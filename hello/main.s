.include "sys.inc"
.include "lcd.inc"
.include "io.inc"

.export main

.code
main:
    jsr io_push_put_byte
    .addr lcd_put_byte
    jsr io_put_const_string
    .asciiz "Hello, world!"
    jsr io_pop_put_byte
    jmp sys_exit

.interruptor irq0_handler, 1

irq0_handler:
    rti

