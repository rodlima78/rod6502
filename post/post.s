.include "via.inc"

POST_STATE_ZP = 0
POST_STATE_STACK = 1
POST_STATE_VIA = 2
POST_STATE_RAM = 3

.import test_zp
.import test_stack
.import test_ram

.export after_test_zp
.export after_test_stack

.zeropage
POST_STAGE: .res 1

.code
main:
    ; initialize stack pointer
    ldx #$ff
    txs

    ; disable interrupts
    sei

    ; Set VIA_PB to output (hopefully it works!)
    lda #$FF
    sta VIA_DIR_B

    ; Turn on red and green leds
    lda #(VIA_LED_GREEN+VIA_LED_RED)
    sta VIA_IO_B

    ; Test zeropage ------------------
    lda #POST_STATE_ZP
    sta POST_STAGE
    jmp test_zp
after_test_zp:
    bne post_fail

    ; Test stack ------------------
    lda #POST_STATE_STACK
    sta POST_STAGE
    jmp test_stack

after_test_stack:
    bne post_fail

    ; Test ram ------------------
    lda #POST_STATE_RAM
    sta POST_STAGE
    jsr test_ram ; here it's ok to use the stack

post_success:
    lda #VIA_LED_GREEN
    sta VIA_IO_B

end:
    stp

post_fail:
    lda #VIA_LED_RED
    sta VIA_IO_B
    bra end

irq:
    rti

.segment "VECTORS"
.word $0000
.word main
.word irq
