.include "irq.inc"
.include "cmd.inc"
.include "lcd.inc"
.include "via.inc"

.import post
.export after_post

.import init_irq
.import irq_handler

.export app_loaded

.zeropage
app_loaded: .res 1

.code
bios_main:
    sei         ; disable interrupts
    ldx #$ff 
    txs         ; initialize stack pointer

.if 1
    jmp post
after_post:
    beq post_ok
    stp         ; post failed, stop the processor.
.else
after_post:
.endif

post_ok:
    jsr init_irq
    jsr lcd_init
    stz app_loaded ; no app loaded yet

    jmp cmd_loop

.segment "VECTORS"
.word $0000 ; nmi, not used
.word bios_main
.word irq_handler
