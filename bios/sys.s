.include "sys.inc"
.include "lcd.inc"

.import cmd_loop
.export import_table
.import save_stack

sys_exit:
    ; restore stack
    ldx save_stack
    txs

    jmp cmd_loop

.rodata
.macro defsymbol sym
    .byte 1+.strlen(.string(sym))+1+2
    .asciiz .string(sym)
    .addr sym
.endmacro

import_table:
    ; must be sorted in ascii order
    defsymbol LCD_MSGBASE
    defsymbol lcd_hex
    defsymbol lcd_string
    defsymbol sys_exit
    .byte 0 ; end-of-table
