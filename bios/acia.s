.include "acia.inc"
.include "via.inc"
.include "irq.inc"
.include "lcd.inc"

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

    ; Timer2 count down pulses on PB6
    lda #%00100000
    sta VIA_ACR

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

; return: A -> character read
acia_get_char:
    lda #%10  ; enable receiver interrupt request
    trb ACIA_CMD

@wait_more:
    wai
    lda ACIA_STATUS
    bit #%1111 ; receiver data register full or any error?
    beq @wait_more   ; no? wait a bit more

    ; test for Overrun (bit2==1)
    ;          Frame error (bit1==1)
    ;          Parity error (bit0==1)
    and #%00000111
    php           ; keep flags for recv result, Z==1 ? ok : failure

    lda #%10 ; disable receiver interrupt request
    tsb ACIA_CMD

    lda ACIA_DATA ; read data even in case of errors, to reset recv error bits
    plp                 

    rts

; input: A -> character to be written out
acia_put_char:
    sta ACIA_DATA

    ; generate interrupt after 10 bits (1+8+1) are output (PB6 is bauds*16)
    lda #(10*16)
    sta VIA_T2CL
    stz VIA_T2CH ; start counter
    wai          ; wait for interrupt
    rts

.zeropage
ADDR_BUFFER: .res 2

.code
; input: string comes right after jsr
acia_put_const_string:
    phx
    ; stack: X Rl Rh
    tsx
    pha
    lda STACK_SEG+2,x
    sta ADDR_BUFFER
    lda STACK_SEG+3,x
    sta ADDR_BUFFER+1

    phy
    ldy #1                      ; ADDR_BUFFER points to 1 byte before the start of string,
                                ; so we start our loop with index == 1
@send_char:
    lda (ADDR_BUFFER),y
    beq @end                    ; end of string (A==0)? go to end
    jsr acia_put_char           ; send character
    iny
    bne @send_char              ; string not too long (y didn't wrap around)? continue
    bra @error                  ; or else go to error

@loop_find_null:
    iny
@error: 
    lda (ADDR_BUFFER),y         ; Y points to character that wasn't tested for \0 yet
    bne @loop_find_null         ; no \0 yet? keep looking for it

@end:
    ; Y points to null terminator
    ; S:(X+2) still points to the buffer address
    tya
    ; Adds Y to return address stored by jsr,
    ; to make it point to the null terminator, which is
    ; one byte before the actual return address, as expected by rts.
    clc
    adc STACK_SEG+2,x
    sta STACK_SEG+2,x
    bcc @skip_high
    inc STACK_SEG+3,x
@skip_high:
    ply
    pla
    plx
    rts

tx_interrupt_handler:
    ldx VIA_T2CL ; clear up Timer2 interrupt flag on VIA
    plx ; was pushed in main handler, time to pop it out
    rti

rx_interrupt_handler:
    ldx ACIA_STATUS ; clear up acia interrupt flag
    plx ; was pushed in main handler, time to pop it out
    rti
