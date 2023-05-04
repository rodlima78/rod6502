.include "sys.inc"
.include "lcd.inc"
.include "mem.inc"
.include "io.inc"
.include "acia.inc"

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
    defsymbol acia_get_byte
    defsymbol acia_put_byte
    defsymbol io_cb_get_byte
    defsymbol io_cb_put_byte
    defsymbol io_get_byte
    defsymbol io_get_hex
    defsymbol io_put_byte
    defsymbol io_put_const_string
    defsymbol io_put_hex
    defsymbol lcd_put_byte
    defsymbol lcd_put_const_string
    defsymbol lcd_put_hex
    defsymbol sys_exit
    defsymbol sys_free
    defsymbol sys_malloc
    .byte 0 ; end-of-table
