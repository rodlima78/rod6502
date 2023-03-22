.include "via.inc"
.include "lcd.inc"

.export test_via
.export test_via_irq

.zeropage
TEST_STATUS: .res 1

.rodata
STR_NO_IRQ:  .asciiz "NO IRQ "
STR_BAD_IFR:  .asciiz "BAD IFR "
STR_MANY_IRQ:  .asciiz "MANY IRQ "

.code

 ; Test VIA -----------------
test_via:
    lda #2 ; irq handler not called
    sta TEST_STATUS

    cli ; enable interrupts

    lda #$C0 ; enable Timer1 interrupts
    sta VIA_IER

    lda #$C0  ; enable timer1 in one-shot mode
    trb VIA_ACR

    ; one-shot after 67 cycles
    lda #67
    sta VIA_T1CL
    stz VIA_T1CH

    ; wait for irq to update state
    ldx #$FF
wait_irq:
    lda #2
    cmp TEST_STATUS 
    bne handler_called ; irq handler called?
    dex
    bne wait_irq
    lcd_print STR_NO_IRQ
    sei ; disable interrupts
    lda #1 ; failure!
    rts
handler_called:
    sei ; disable interrupts
    lda TEST_STATUS
    rts

test_via_irq:
    lda VIA_T1CL ; reset the timer interrupt

    dec TEST_STATUS ; 2 -> 1
    dec TEST_STATUS ; 1 -> 0
    beq test_via_irq_continue ; test_status == 0 ? successs

    lcd_print STR_MANY_IRQ
    bra end_irq 

test_via_irq_continue:

    lda VIA_IFR
    bit #$C0 ; IRQ & Timer1 ?
    beq end_irq
    inc TEST_STATUS ; 0 -> 1 (failure)
    lcd_print STR_BAD_IFR
end_irq:
    rts
