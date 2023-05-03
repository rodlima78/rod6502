.include "cmd.inc"
.include "acia.inc"
.include "via.inc"
.include "lcd.inc"
.include "strlist.inc"

PROMPT = '>'

.feature string_escapes
.feature loose_char_term

.segment "ZPTMP": zeropage
idx_cmd_buffer: .res 1
pcmd: .res 2

.code
cmd_loop:
    jsr acia_start
    lda #0
    sta VIA_IO_B

    jsr parse_cmd

    lda pcmd+1      ; when testing for fn pointers, we only have to test MSB
    beq cmd_loop    ; cmd failed
    jmp (pcmd)
    bra cmd_loop

.rodata
.macro def_cmd_handler name, sym
    .byte 1+.strlen(.string(name))+1+2
    .asciiz .string(name)
    .addr sym
.endmacro
cmd_jumptable:
    def_cmd_handler load, cmd_load
    def_cmd_handler run, cmd_run
    .byte 0 ; end of table

.segment "ZPTMP": zeropage
CMD_BUFFER: .res 16

.code
parse_cmd:
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

    ; our pointer to the character to be returned by item_read_byte
    stz idx_cmd_buffer
    
    ; just one item
    lda #1
    sta strlist_len
    stz strlist_len+1

    lda #<cmd_jumptable
    sta strlist
    lda #>cmd_jumptable
    sta strlist+1

    lda #<item_found
    sta strlist_cb_found
    lda #>item_found
    sta strlist_cb_found+1

    lda #<item_not_found
    sta strlist_cb_not_found
    lda #>item_not_found
    sta strlist_cb_not_found+1

    lda #<item_read_byte
    sta strlist_cb_read_byte
    lda #>item_read_byte
    sta strlist_cb_read_byte+1

    jsr process_strlist
    rts

item_read_byte:
    ldx idx_cmd_buffer         ; strlist_cb_read_byte doesn't require us to preserve X
    lda CMD_BUFFER,x
    cmp #' '    ; space marks the end of the command, the rest is parameters
    bne @ret
    lda #0
@ret:
    inc idx_cmd_buffer
    rts

item_found:
    ; Set pcmd to the address of the cmd function to be called
    lda (strlist_ptr),y
    sta pcmd
    iny
    lda (strlist_ptr),y
    sta pcmd+1
    iny
    rts

item_not_found:
    ; set pcmd to NULL, indicating invalid command
    stz pcmd
    stz pcmd+1

    jsr acia_put_const_string
    .asciiz "invalid command\r\n"
    rts

