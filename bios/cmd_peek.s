.include "cmd.inc"
.include "io.inc"
.include "acia.inc"

.import cmdline_get_byte
.feature string_escapes

.segment "ZPTMP": zeropage
ptr: .res 2

.code
error:
    jsr io_put_const_string
    .asciiz "Syntax error"
    jsr io_pop_get_byte
    jmp cmd_loop

cmd_peek:
    ; Input from cmdline
    jsr io_push_get_byte
    .addr cmdline_get_byte

    ; Skip spaces at beginning of cmdline
    jsr io_get_skip_space
    bcs error

    ; check if there are no parameters
    jsr io_get_byte
    bcs error
    cmp #0
    beq error
    jsr io_get_putback

    ; Parse starting address
    jsr io_get_hex ; get addr MSB
    sta ptr+1
    bcs error
    jsr io_get_hex ; get addr LSB
    sta ptr
    bcs error

    ; no more arguments!
    jsr io_get_byte
    cmp #0
    bne error

    ; load byte
    lda (ptr)

    ; write it out
    jsr io_put_hex

    jmp cmd_loop

    
