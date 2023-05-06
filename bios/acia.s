.include "acia.inc"
.include "via.inc"
.include "irq.inc"
.include "lcd.inc"
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

    ; set our rx irq handler to IRQ0 (linked to ACIA)
    lda #<rx_interrupt_handler
    sta irq_table+0*2+0
    lda #>rx_interrupt_handler
    sta irq_table+0*2+1

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

    lda #(BAUDS_9600 | DATABIT_8 | STOPBIT_1)
    sta ACIA_CTRL

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

    ; disable acia interrupts
    lda #%10
    tsb ACIA_CMD

    pla
    rts

acia_stop:
    pha

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
@end:           ; yes, channel is empty
    pla
    rts

.zeropage
; 3: need to wait / waiting 64k cycles
; 2: waiting 64k cycles 
; 1: waiting 22528 cycles
; 0: timed out!
timeout_state: .res 1

.code
; input: A -> timeout (seconds)
; return: A -> character read
; C==1 in case of errors
acia_get_byte_timeout:
    ; for 9600 bauds, 1 second wait == 65536*2 + 22528 ($5800) bauds*16 pulses
    phx

    tax ; X now holds how many seconds to wait

    cpx #0
    beq @no_timeout

    lda #%00100000 ; Timer2 count down pulses on PB6
    sta VIA_ACR

@wait_one_second:
    lda #3
    sta timeout_state

    lda #255
    sta VIA_T2CL
    sta VIA_T2CH ; start counter
    bra @enable_acia_interrupt

@no_timeout:
    stz timeout_state

@enable_acia_interrupt:
    lda #%10  ; enable receiver interrupt request
    trb ACIA_CMD

@wait_more:
    wai
    cpx #0              ; doesn't have timeout?
    beq @ignore_timeout ; yes, ignore it
    lda timeout_state   ; no, timeout_state==0?
    beq @timed_out      ; yes, signal timeout
@ignore_timeout:
    lda ACIA_STATUS
    bit #%1111 ; receiver data register full or any error?
    beq @wait_more   ; no? wait a bit more
    and #.lobyte(~%1000) ; signal no timeout (we don't need data register full info anymore)
    bra @check_errors

@timed_out:
    dex
    bne @wait_one_second
    lda ACIA_STATUS
    ora #%1000 ; bit3=1 -> timeout

@check_errors:
    plx ; x not needed anymore

    ; test for Timeout (bit3==1)
    ;          Overrun (bit2==1)
    ;          Frame error (bit1==1)
    ;          Parity error (bit0==1)
    and #%00001111
    clc
    adc #$FF        ; if A==0, C==0 or in case of errors, C==1

    stz VIA_ACR   ; disable Timer2 pulse counter

    lda #%10 ; disable receiver interrupt request
    tsb ACIA_CMD

    lda ACIA_DATA ; read data even in case of errors, to reset recv error bits

    rts

acia_get_byte:
    lda #0
    jsr acia_get_byte_timeout
    rts

; input: A -> character to be written out
acia_put_byte:
    sta ACIA_DATA
    stz timeout_state ; so that interrupt handler won't using it
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
    dec timeout_state
    beq @timed_out ; 0 ? timeout
    cmp #3         ; 3 <= state (before decrement) ?
    bcs @wait_64k  ; yes, wait 64k cycles

    stz VIA_T2CL   ; no, wait for 22528 cycles ($5800)
    lda #$58
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

rx_interrupt_handler:
    ldx ACIA_STATUS ; clear up acia interrupt flag
    plx ; was pushed in main handler, time to pop it out
    rti
