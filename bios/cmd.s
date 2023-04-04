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

STR_LOAD: .asciiz "load"
STR_RUN: .asciiz "run"

.zeropage
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
    jsr acia_get_char
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

@backspace:
    cpx #0
    beq @get_char
    dex
    jsr acia_put_const_string
    .asciiz "\x08 \x08"
    bra @get_char

@got_cmd:
    jsr acia_put_char ; echo line feed back to terminal
    stz CMD_BUFFER,x ; NUL marks end of buffer

    ; Now let's compare the cmd string against the commands we define
@compare_load:
    ldx #0 
@loop_load:
    lda CMD_BUFFER,x
    cmp STR_LOAD,x   ; compare cmd and "load"
    bne @compare_run ; different? try "run"
    inx
    cpx #.sizeof(STR_LOAD) ; reached end of "load" string?
    bne @loop_load      ; no? continue comparison
    lda #CMD_LOAD
    rts

@error:
    jsr acia_put_const_string
    .asciiz "invalid command\r\n"
    bra @prompt

@compare_run:
    ldx #0 
@loop_run:
    lda CMD_BUFFER,x
    cmp STR_RUN,x   ; compare cmd and "run"
    bne @error ; different? error!
    inx
    cpx #.sizeof(STR_RUN) ; reached end of "load" string?
    bne @loop_run      ; no? continue comparison
    lda #CMD_RUN
    rts
