.include "via.inc"
.include "irq.inc"

POST_STAGE_ZP = 0
POST_STAGE_STACK = 1
POST_STAGE_IRQ = 2
POST_STAGE_RAM = 3

.import test_zp
.import test_stack
.import test_ram
.import test_irq
.import test_irq_handler

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
    lda #POST_STAGE_ZP
    sta POST_STAGE
    jmp test_zp
after_test_zp:
    beq test_zp_ok
    jmp post_fail
test_zp_ok:

    ; from now on we can use zeropage

    ; Test stack ------------------
    lda #POST_STAGE_STACK
    sta POST_STAGE
    jmp test_stack
after_test_stack:
    beq test_stack_ok
    jmp post_fail
test_stack_ok:

    ; Test IRQ ------------------
    lda #POST_STAGE_IRQ
    sta POST_STAGE

    jsr test_irq
    bne post_fail

    ; Test ram ------------------
    lda #POST_STAGE_RAM
    sta POST_STAGE

    jsr test_ram
    bne post_fail

post_success:
    lda #VIA_LED_GREEN
    sta VIA_IO_B
    stp

post_fail:
    lda #VIA_LED_RED
    sta VIA_IO_B
    stp

irq:
    pha

    lda #POST_STAGE_IRQ
    cmp POST_STAGE
    bne irq_end ; not correct state?
    jsr test_irq_handler

irq_end:
    pla
    rti

.segment "VECTORS"
.word $0000
.word main
.word irq
