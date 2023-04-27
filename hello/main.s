.include "sys.inc"
.include "lcd.inc"

.rodata
HELLO: .asciiz "Hello, world!"

.code
main:
    lcd_print HELLO
    jmp sys_exit

.interruptor irq0_handler, 1

irq0_handler:
    rti

