.include "irq.inc"
.include "via.inc"

.export irq_table

.export after_post
.import post

.code
bios_main:
    sei         ; disable interrupts

    ldx #$ff 
    txs         ; initialize stack pointer

    jmp post
after_post:
    beq post_ok
    stp

post_ok:
    ; initialize IRQ jump table with the default handler
    ldx #(8*2)
@loop:
    ; copy MSB (we're going from back to front)
    lda #>default_irq_handler
    sta irq_table-1,x
    dex
    ; copy LSB
    lda #<default_irq_handler
    sta irq_table-1,x
    dex
    bne @loop

    cli         ; enable interrupts

    stp

.segment "IRQ_TABLE"
irq_table:
    .res 8*2 ; one address per IRQ line

.code
default_irq_handler:
    plx
    rti

irq_handler:
    phx
    ldx IRQ_CTRL       ; read the IRQ line (X == line*2)
    jmp (irq_table,x)  ; jump to its handler

.segment "VECTORS"
.word $0000 ; nmi, not used
.word bios_main
.word irq_handler
