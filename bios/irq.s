.include "irq.inc"

.export init_irq
.export irq_table
.export default_irq_handler
.export irq_handler

.code
init_irq:
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

    ; enable all interrupt levels
    lda #$FF
    sta IRQ_CTRL

    cli         ; enable interrupts
    rts

default_irq_handler:
    plx
    rti

.segment "IRQ_TABLE"
irq_table:
    .res 8*2 ; one address per IRQ line

.code
irq_handler:
    phx
    ldx IRQ_DATA       ; read the IRQ line (X == line*2)
    jmp (irq_table,x)  ; jump to its handler

