.include "acia.inc"
.include "via.inc"
.include "irq.inc"
.include "io.inc"

.import default_irq_handler
.import irq_table

STACK_SEG = $0100

BAUDS_115k2 = %10000
BAUDS_50 = %10001
BAUDS_75 = %10010
BAUDS_109_92 = %10011
BAUDS_134_58 = %10100
BAUDS_150 = %10101
BAUDS_300 = %10110
BAUDS_600 = %10111
BAUDS_1200 = %11000
BAUDS_1800 = %11001
BAUDS_2400 = %11010
BAUDS_3600 = %11011
BAUDS_4800 = %11100
BAUDS_7200 = %11101
BAUDS_9600 = %11110
BAUDS_19200 = %11111

STOPBIT_1 = 0
STOPBIT_2 = $80

DATABIT_8 = %00000000
DATABIT_7 = %00100000
DATABIT_6 = %01000000
DATABIT_5 = %01100000

; must be a power of two
RDBUFSIZE = 8

.data
; circular buffer for read data
read_buffer: .res RDBUFSIZE
; index of where new bytes will be written to
buffer_put: .res 1
; index of next byte to be read from
; if $FF, read_buffer[0] has the error state
buffer_get: .res 1

.code
acia_start:
    pha

    lda ACIA_CMD
    bit #1          ; data terminal is ready?
    beq @must_setup ; no, must set it up
    pla             ; yes, early return
    rts
@must_setup:
    ; PB6 is input
    lda #$40
    trb VIA_DIR_B

    ; enable interrupts on timer2
    lda #((1<<5) | $80)
    sta VIA_IER

    ; set our tx irq handler to IRQ1 (linked to VIA)
    lda #<tx_interrupt_handler
    sta irq_table+1*2+0
    lda #>tx_interrupt_handler
    sta irq_table+1*2+1

    ; Disable IRQ2 and lower.
    ; Only keep IRQ0 (ACIA) and IRQ1 (VIA)
    lda #2
    sta IRQ_CTRL

    ; Program reset
    lda #0
    sta ACIA_STATUS

    lda #(BAUDS_115k2 | DATABIT_8 | STOPBIT_1)
    sta ACIA_CTRL

    ; special handler while we wait for carrier
    lda #<rx_interrupt_handler_wait_carrier
    sta irq_table+0*2+0
    lda #>rx_interrupt_handler_wait_carrier
    sta irq_table+0*2+1

    ; data terminal ready (b0==1)
    ; recv irq enabled (b1==0)
    ; ready to send yes  (b2-3 == %10)
    ; no echo(b4 == 0)
    lda #%01001
    sta ACIA_CMD

    ; Wait till we detect a carrier
@loop_wait_ready:
    wai
@wait_ready:
    lda #%00100000
    bit ACIA_STATUS
    bne @loop_wait_ready

    sei ; disable interrupts (our "mutex")

    ; reset circular read buffer
    stz buffer_put
    stz buffer_get

    ; set our rx irq handler to IRQ0 (linked to ACIA)
    lda #<rx_interrupt_handler
    sta irq_table+0*2+0
    lda #>rx_interrupt_handler
    sta irq_table+0*2+1

    cli ; enable interrupts

    pla
    rts

acia_stop:
    pha

    ; disable acia interrupts
    lda #%10
    tsb ACIA_CMD

    ; b0->0: data terminal not ready
    lda #1
    trb ACIA_CMD

    ; disable Timer2 pulse counter
    lda #%00000000
    sta VIA_ACR

    ; restore IRQ0 handler to default
    lda #<default_irq_handler
    sta irq_table+0*2+0
    lda #>default_irq_handler
    sta irq_table+0*2+1

    ; restore IRQ1 handler to default
    lda #<default_irq_handler
    sta irq_table+1*2+0
    lda #>default_irq_handler
    sta irq_table+1*2+1

    ; enable all IRQs
    lda #$ff
    sta IRQ_CTRL

    pla
    rts

acia_enable_echo:
    pha
    lda ACIA_CMD
    and #%11100011
    ora #%00010000
    sta ACIA_CMD
    pla
    rts

acia_disable_echo:
    pha
    lda ACIA_CMD
    and #%11100011
    ora #%00001000
    sta ACIA_CMD
    pla
    rts

; Purges the recv channel. We get chars until
; we get a timeout.
acia_purge:
    pha 
@retry:
    lda #1      ; 1s timeout
    jsr acia_get_byte_timeout
    bcc @retry  ; got char (no error)? get next char
    bit #%1000  ; timeout?
    beq @retry  ; no (some other error)? try again
    pla          ; yes, channel is empty
    rts

.zeropage
; For 9600
; 3: need to wait / waiting 64k cycles
; 2: waiting 64k cycles 
; 1: waiting 22528 cycles
; 0: timed out!
; For 115200
; 29: need to wait / waiting 64k cycles
; 28->2: waiting 27*64k cycles 
; 1: waiting 8192 cycles
; 0: timed out!
timeout_state: .res 1

.code
; input: A -> timeout (seconds)
; return: A -> character read
; C==1 in case of errors
acia_get_byte_timeout:
    ; for 9600 bauds, 1 second wait == 65536*2 + 22528 ($5800) bauds*16 pulses
    ; for 115200 bauds, 1 second wait == 65536*28 + 8192 ($2000) bauds*16 pulses
    phx
    phy
    tay ; y now holds how many seconds to wait

@read_data:
    sei ; disable interrupts
    ; buffer in error state?
    ldx buffer_get
    bmi @buffer_error
    ; if read_buffer is empty (get == put)
    cpx buffer_put
    beq @buffer_empty       ; yes, wait for more data
    lda read_buffer,x       ; no, return data from it

    ; increment get pointer, modulo RDBUFSIZE
    pha
    inx
    txa
    and #(RDBUFSIZE-1)
    sta buffer_get
    pla

    cli ; enable interrupts

    clc
    bra @end

@buffer_error:
    ; reset circular buffer
    stz buffer_get
    stz buffer_put
    lda read_buffer   ; get error status
    cli
    sec     ; indicate error
    bra @end

@buffer_empty:
    cli
    stz timeout_state
    cpy #0      ; no timeout?
    beq @wait   ; go straight to wait for more data to come

    lda #%00100000 ; Timer2 count down pulses on PB6
    sta VIA_ACR

@wait_one_second:
    lda #29
    sta timeout_state

    lda #255     ; wait for 64k cycles
    sta VIA_T2CL
    sta VIA_T2CH ; start counter
@wait:
    wai                 ; wait for some interrupt to happen (rx or timer)
    cpy #0              ; does it have timeout?
    beq @read_data      ; no, read byte
    lda timeout_state   ; yes. timeout_state==0?
    bne @got_data       ; no, read byte
    dey                 ; yes, one less second to wait
    bne @wait_one_second
    
    ; timeout!
    lda #%1000 ; bit3=1 -> timeout
    stz VIA_ACR   ; disable Timer2 pulse counter
    sec
    bra @end
@got_data:
    sei
    ldx buffer_get
    cpx buffer_put
    cli
    beq @wait

    stz VIA_ACR   ; disable Timer2 pulse counter
    bra @read_data
@end:
    ply
    plx         ; pop caller's x
    rts

acia_get_byte:
    lda #0
    jsr acia_get_byte_timeout
    rts

; input: A -> character to be written out
acia_put_byte:
    sta ACIA_DATA
    stz timeout_state ; so that interrupt handler skips timer handling
    pha

    ; generate interrupt after 10 bits (1+8+1) are output (PB6 is bauds*16)
    lda #%00100000 ; Timer2 count down pulses on PB6
    sta VIA_ACR
    lda #(10*16)
    sta VIA_T2CL
    stz VIA_T2CH ; start counter
    pla
    wai          ; wait for interrupt
    rts

.zeropage
ADDR_BUFFER: .res 2

.code
tx_interrupt_handler:
    pha
    lda timeout_state
    beq @timed_out ; 0 ? timeout
    dea
    sta timeout_state
    beq @timed_out ; 0 ? timeout
    cmp #2         ; 2 <= state?
    bcs @wait_64k  ; yes, wait 64k cycles

    stz VIA_T2CL   ; no, wait for (9600 Bd) $5800 or (115200 Bd) $2000 cycles
    lda #$20
    sta VIA_T2CH ; start counter
    bra @end
@wait_64k:
    lda #255
    sta VIA_T2CL
    sta VIA_T2CH ; start counter
    bra @end

@timed_out:
    ldx VIA_T2CL ; clear up Timer2 interrupt flag on VIA

@end:
    pla
    plx ; was pushed in main handler, time to pop it out
    rti

rx_interrupt_handler_wait_carrier:
    lda ACIA_STATUS ; clear up acia interrupt flag
    plx ; was pushed in main handler, time to pop it out
    rti

rx_interrupt_handler:
    pha

    lda ACIA_STATUS ; clear up acia interrupt flag
    ; test for Overrun (bit2==1)
    ;          Frame error (bit1==1)
    ;          Parity error (bit0==1)
    bit #%0111
    bne @error
    bit #%1000      ; data arrived?
    beq @end        ; no, do nothing
    lda ACIA_DATA
    ldx buffer_put
    sta read_buffer,x
    ; increment put index, modulo RDBUFSIZE
    inx
    txa
    and #(RDBUFSIZE-1)
    sta buffer_put
    cmp buffer_get
    bne @end
    lda #%100           ; buffer overrun
@error:
    ldx ACIA_DATA       ; clear input and ignore it
    sta read_buffer     ; write status to read_buffer[0]
    lda #$ff        
    sta buffer_get      ; indicate error
@end:
    pla
    plx ; was pushed in main handler, time to pop it out
    rti
