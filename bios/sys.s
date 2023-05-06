.include "sys.inc"
.include "lcd.inc"
.include "mem.inc"
.include "io.inc"
.include "acia.inc"
.include "via.inc"

.import cmd_loop
.export import_table
.import save_stack
.importzp app_loaded

STACK_SEG = $0100

.segment "ZPTMP": zeropage
abort_msg: .res 2

.code
sys_exit:
    ; restore stack
    ldx save_stack
    txs

    ; app not loaded anymore
    stz app_loaded

    jmp cmd_loop

; =====================================================
; asciiz must follow jsr sys_abort
sys_abort:
    tsx
    lda STACK_SEG+1,x
    sta abort_msg 
    lda STACK_SEG+2,x
    sta abort_msg+1

    ldy #1                      ; ADDR_BUFFER points to 1 byte before the start of string,
@send_char:
    lda (abort_msg),y
    beq @end                    ; end of string (A==0)? go to end
    jsr lcd_put_byte            ; send character
    iny
    bne @send_char              ; string not too long (y didn't wrap around)? continue

@end:
    ; turn on red led
    lda #(VIA_LED_GREEN+VIA_LED_RED)
    tsb VIA_DIR_B
    lda #VIA_LED_RED
    sta VIA_IO_B

    stp

.rodata
.macro defsymbol sym
    .byte 1+.strlen(.string(sym))+1+2
    .asciiz .string(sym)
    .addr sym
.endmacro

import_table:
    ; must be sorted in ascii order
    defsymbol acia_get_byte
    defsymbol acia_get_byte_timeout
    defsymbol acia_put_byte
    defsymbol io_get_byte
    defsymbol io_get_hex
    defsymbol io_get_putback
    defsymbol io_get_skip_space
    defsymbol io_pop_get_byte
    defsymbol io_pop_put_byte
    defsymbol io_push_get_byte
    defsymbol io_push_put_byte
    defsymbol io_put_byte
    defsymbol io_put_const_string
    defsymbol io_put_hex
    defsymbol lcd_put_byte
    defsymbol lcd_put_hex
    defsymbol sys_abort
    defsymbol sys_exit
    defsymbol sys_free
    defsymbol sys_malloc
    .byte 0 ; end-of-table
