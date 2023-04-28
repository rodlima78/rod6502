.include "cmd.inc"
.include "acia.inc"
.include "via.inc"
.include "lcd.inc"

PROMPT = '>'

.feature string_escapes
.feature loose_char_term

.code
cmd_loop:
    jsr acia_start
    lda #0
    sta VIA_IO_B

    jsr read_cmd
    asl ; A*2 -> index to addr table of chosen command
    tax
    jmp (cmd_jumptable,x)

.rodata
cmd_jumptable:
    .addr cmd_load
    .addr cmd_run

CMD_LOAD  = 0
CMD_RUN   = 1

STR_LOAD: .asciiz "load"
STR_RUN: .asciiz "run"

.segment "ZPTMP": zeropage
CMD_BUFFER: .res 8

.code
read_cmd:
    jsr acia_put_const_string
    .asciiz "\r\n"

@prompt:
    lda #PROMPT
    jsr acia_put_char

    lda #VIA_LED_GREEN
    sta VIA_IO_B

    ldx #0 ; points to address to store next char to be read
@get_char:
    lda #0 ; no timeout
    jsr acia_get_char
    bne @comm_error
    cmp #$0d            ; line feed?
    beq @got_cmd        ; yes, command was entered
    cmp #$08            ; backspace?
    beq @backspace
    cpx #.sizeof(CMD_BUFFER) ; reached end of buffer space?
    beq @buffer_overflow     ; yes, show error
    sta CMD_BUFFER,x    ; no, append character to buffer
    jsr acia_put_char   ; echo it back
    inx                 ; bump next address
    bra @get_char

@buffer_overflow:
    jsr acia_put_const_string
    .asciiz "\r\ncommand too large\r\n"
    bra @prompt

@comm_error:
    jsr acia_put_const_string
    .asciiz "\r\ncommunication error\r\n"
    bra @prompt

@backspace:
    cpx #0
    beq @get_char
    dex
    jsr acia_put_const_string
    .asciiz "\x08 \x08"
    bra @get_char

@got_cmd:
    jsr acia_put_const_string
    .asciiz "\r\n"
    stz CMD_BUFFER,x ; NUL marks end of buffer

    ; Now let's compare the cmd string against the commands we define

.macro compare str, next
    ldx #0 
:   lda CMD_BUFFER,x
    cmp str,x         ; compare cmd and "load"
    bne next          ; different? try next one
    inx
    cpx #.sizeof(str) ; reached end of string?
    bne :-            ; no? continue comparison
.endmacro

@compare_run:
    compare STR_RUN, @compare_load
    lda #CMD_RUN
    rts

@compare_load:
    compare STR_LOAD, @error_invalid_cmd
    lda #CMD_LOAD
    rts

@error_invalid_cmd:
    jsr acia_put_const_string
    .asciiz "invalid command\r\n"
    jmp @prompt

