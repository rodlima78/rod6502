.include "cmd.inc"
.include "io.inc"
.include "acia.inc"

.import cmdline_get_byte
.feature string_escapes

STACK_ADDR = $0100

.segment "ZPTMP": zeropage
ptr: .res 2

.code
error:
    jsr io_put_const_string
    .asciiz "Syntax error"
    jsr io_pop_get_byte
    jmp cmd_loop

cmd_mdump:
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
    beq @no_arguments
    jsr io_get_putback

    ; Parse starting address
    jsr io_get_hex ; get addr MSB
    bcs error
    sta ptr+1
    jsr io_get_hex ; get addr LSB
    sta ptr
    bcs error

    ; no more arguments!
    jsr io_get_byte
    cmp #0
    bne error

@no_arguments:
    lda ptr

    ; Set up pointer and offset from row starting address
    pha           ; push addr LSB
    and #$0F      ; calculate offset
    tay           ; store offset in Y
    pla           ; pop addr LSB
    ; make row address aligned to 16 bytes
    and #$F0
    sta ptr

    lda #16
    pha           ; push row count

    phy           ; push offset
    tsx           ; X+1 = index to 'offset' on stack
@new_row:
    ; Write row starting address ------------------
    lda ptr+1
    jsr io_put_hex
    lda ptr
    jsr io_put_hex
    lda #' '
    jsr io_put_byte

    ; Write initial padding -----------------------
    lda #0  ; how much padding we've added so far
@padding:
    cmp STACK_ADDR+1,x  ; get offset directly from stack
    beq @end_padding    ; no more padding to output? done
    jsr io_put_const_string
    .asciiz " .."
    inc
    cmp #8
    bne @padding
    pha     ; push current padding count
    lda #' '
    jsr io_put_byte
    pla     ; pop current padding count
    bra @padding
@end_padding:

    ; Write hex bytes ------------------------
    pla     ; pop offset from stack
    pha     ; push it back, we're gonna need it
    tay     ; offset must be on Y
@loop8:
    lda #' '
    jsr io_put_byte
    lda (ptr),y
    jsr io_put_hex
    iny     ; next address
    tya
    bit #7  ; end 8-byte block?
    bne @loop8 ; no, carry on
    lda #' '    
    jsr io_put_byte ; one more space
    cpy #16    ; end of row?
    bne @loop8 ; no, carry on

    ; Write printable bytes ---------------------
    ply     ; pop offset
    beq @end_byte_padding ; no offset? no more byte padding to do
    ; Write padding
    phy     ; push offset
    lda #' '
@loop_padding:
    jsr io_put_byte
    dey
    bne @loop_padding
    ply     ; pop offset

@end_byte_padding:
    lda #'|'
    jsr io_put_byte

@loop16:
    lda (ptr),y
    cmp #$20    ; byte < $20 (spc)
    bcc @replace
    cmp #$7F    ; byte >= $7F (del)
    bcs @replace
    bra @print
@replace:
    lda #'.'    ; for non-printable chars
@print:
    jsr io_put_byte
    iny         ; next byte
    cpy #16     ; end of row?
    bne @loop16 ; no, carry on

    jsr io_put_const_string
    .asciiz "|\r\n"

    ; ptr = ptr+16 (next row)
    lda #16
    clc
    adc ptr
    sta ptr
    bcc @skip_msb
    inc ptr+1
@skip_msb:
    pla     ; pop row count
    dec
    pha

    ldy #0  ; start of new row
    phy     ; push 0 offset
    tsx     ; X+1 = offset on stack

    cmp #0  ; row count==0?
    beq @exit_loop_rows ; yeah, we're finished
    jmp @new_row
@exit_loop_rows:

    jsr io_pop_get_byte
    jmp cmd_loop

    





