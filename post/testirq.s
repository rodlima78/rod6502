.include "via.inc"
.include "irq.inc"

.export test_irq
.export test_irq_handler

.zeropage
TEST_STATUS: .res 1

.code

test_irq:
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
    lda #1 ; failure!
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
    rts ; Z==0, A!=0: failed!
handler_not_called:
    dex
    bne wait_irq2

    lda VIA_T1CL ; reset the timer1 interrupt (just in case)

    sei ; disable interrupts
    lda #0 ; success!
    rts

test_irq_handler:
    dec TEST_STATUS ; 2 -> 1
    dec TEST_STATUS ; 1 -> 0
    bne end_handler ; test_status != 0 ? fail

    lda IRQ_CTRL
    cmp #(1<<1) ; VIA is IRQ1
    beq end_handler
    inc TEST_STATUS ; 0 -> 1 (failure)
end_handler:
    ; disable only now, after we checked IFR
    lda VIA_T1CL ; reset the timer interrupt
    rts
