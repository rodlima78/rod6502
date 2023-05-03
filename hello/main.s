.include "sys.inc"
.include "lcd.inc"

.export main

.code
main:
    jsr lcd_put_const_string
    .asciiz "Hello, world!"
    jmp sys_exit

.interruptor irq0_handler, 1

irq0_handler:
    rti

