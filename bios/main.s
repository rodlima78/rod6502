.include "irq.inc"
.include "cmd.inc"
.include "lcd.inc"
.include "via.inc"
.include "io.inc"

.import post
.export after_post

.import init_irq
.import init_mem
.import irq_handler
.import init_app_loader


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
    jsr init_mem   ; run first to initialize heap and data seg
    jsr init_irq
    jsr lcd_init
    jsr init_app_loader

    jmp cmd_loop

.segment "VECTORS"
.word $0000 ; nmi, not used
.word bios_main
.word irq_handler
