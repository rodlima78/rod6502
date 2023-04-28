.include "via.inc"
.include "lcd.inc"
.include "irq.inc"

.importzp STATUS_STR
.import irq_table
.export test_irq

.segment "ZPTMP": zeropage
TEST_STATUS: .res 1

.rodata
STR_ERROR_NO_IRQ: .asciiz "NO INTERRUPT"
STR_ERROR_MASK:   .asciiz "MASK ERROR"
STR_ERROR_SPURIOUS_IRQ: .asciiz "SPURIOUS IRQ"
STR_ERROR_BAD_CODE: .asciiz "BAD CODE"

.code

test_irq:
    ; initialize IRQ jump table with our handler
    ldx #(8*2)
@loop:
    ; copy MSB (we're going from back to front)
    lda #>test_irq_handler
    sta irq_table-1,x
    dex
    ; copy LSB
    lda #<test_irq_handler
    sta irq_table-1,x
    dex
    bne @loop

    lda #2 ; irq handler not called
    sta TEST_STATUS

    ; allow only IRQ0 and 1
    lda #$2
    sta IRQ_CTRL

    lda #$7F ; disable all VIA interrupts
    sta VIA_IER

    lda #$C0 ; enable Timer1 interrupts (only)
    sta VIA_IER

    lda #$C0  ; enable timer1 in one-shot mode
    trb VIA_ACR

    cli ; enable interrupts

    ; one-shot after 128 cycles
    lda #128
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

    sei ; disable interrupts
    lda VIA_T1CL ; reset the timer interrupt just in case
    lda #<STR_ERROR_NO_IRQ
    sta STATUS_STR
    lda #>STR_ERROR_NO_IRQ
    sta STATUS_STR+1
    rts
handler_called:

    ; now we mask IRQ1 (VIA) and trigger Timer1 again,
    ; IRQ1 must not be signaled.
    
    ; mask out IRQ1 and above
    lda #1
    sta IRQ_CTRL

    ; set status to "not called"
    lda #2
    sta TEST_STATUS 

    lda #$C0  ; enable timer1 in one-shot mode
    trb VIA_ACR

    cli ; enable interrupts (just to make sure)

    ; one-shot after 16 cycles
    lda #16
    sta VIA_T1CL
    stz VIA_T1CH

    ; wait long enough to make sure interrupt won't be signaled
    ldx #$FF
wait_irq2:
    lda #2
    cmp TEST_STATUS 
    beq handler_not_called
    ; failed!
    lda #<STR_ERROR_MASK
    sta STATUS_STR
    lda #>STR_ERROR_MASK
    sta STATUS_STR+1
    rts
handler_not_called:
    dex
    bne wait_irq2

    lda VIA_T1CL ; reset the timer1 interrupt (just in case)

    sei ; disable interrupts
    rts

test_irq_handler:
    plx ; need to pull X that was pushed in main's irq_handle

    dec TEST_STATUS ; 2 -> 1
    dec TEST_STATUS ; 1 -> 0
    beq continue_handler ; test_status == 0 ? ok

    lda #<STR_ERROR_SPURIOUS_IRQ
    sta STATUS_STR
    lda #>STR_ERROR_SPURIOUS_IRQ
    sta STATUS_STR+1

    bra end_handler
continue_handler:

    lda IRQ_DATA
    cmp #(1<<1) ; VIA is IRQ1
    beq end_handler
    inc TEST_STATUS ; 0 -> 1 (failure)
    lda #<STR_ERROR_BAD_CODE
    sta STATUS_STR
    lda #>STR_ERROR_BAD_CODE
    sta STATUS_STR+1

end_handler:
    ; disable only now, after we checked IFR
    lda VIA_T1CL ; reset the timer interrupt
    rti
