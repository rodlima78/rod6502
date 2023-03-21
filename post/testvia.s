.include "via.inc"

POST_STATE_VIA_WAIT = 2
POST_STATE_VIA_OK = 3

POST_STATE = $0000
IRQ_CALLED = $0001
IRQ_FAIL = $0002

.code

reset:
 ; initialize stack pointer
 ldx #$ff
 txs

 ; Test VIA -----------------
test_via:
 lda #POST_STATE_VIA_WAIT
 sta POST_STATE

 stz IRQ_CALLED
 stz IRQ_FAIL

 lda #$ff
 sta VIA_DIR_B ; set all B pins to output (for the leds)

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
wait_via_irq:
 lda #POST_STATE_VIA_OK
 cmp POST_STATE
 beq test_via_ok
 dex
 beq post_fail
 bra wait_via_irq
test_via_ok:
 lda #0
 cmp IRQ_FAIL
 bne post_fail

post_success:
 lda #(VIA_LED_GREEN)
 sta VIA_IO_B

end:
 stp

post_fail:
 lda #(VIA_LED_RED)
 sta VIA_IO_B
 bra end

irq:
 pha
 inc IRQ_CALLED
 bit #$C0 ; IRQ & Timer1
 bne irq_fail

 lda #1
 cmp IRQ_CALLED
 bne irq_fail ; irq_called != 1 ? fail

 lda #POST_STATE_VIA_WAIT
 cmp POST_STATE
 bne irq_fail ; POST_STATE != POST_STATE_VIA_WAIT ? fail

end_irq:
 lda #POST_STATE_VIA_OK
 sta POST_STATE

 lda VIA_T1CL ; reset the timer interrupt
 pla
 rti

irq_fail:
 lda #VIA_LED_RED
 sta VIA_IO_B
 bra end_irq

nmi:
 rti

.segment "VECTORS"
.word nmi
.word reset
.word irq
