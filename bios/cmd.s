.include "cmd.inc"
.include "acia.inc"
.include "via.inc"
.include "lcd.inc"
.include "strlist.inc"
.include "io.inc"

.export cmdline_get_byte
.export cmdline_put_back
.import io_clear_put_stack
.import io_clear_get_stack

PROMPT = '>'

.feature string_escapes
.feature loose_char_term

.segment "ZPTMP": zeropage
idx_cmd_buffer: .res 1
pcmd: .res 2

.data
CMD_BUFFER: .res 16

.code

cmdline_get_byte:
    phx
    ldx idx_cmd_buffer
    lda CMD_BUFFER,x
    beq @end              ; end of string? do not increment idx
    inx
    stx idx_cmd_buffer    ; 'inx + stx zp' takes 5 clks, 'inc zp' takes 6
@end:
    plx
    clc
    rts

cmdline_put_back:
    dec idx_cmd_buffer
    rts

cmd_loop:
    jsr acia_start
    lda #0
    sta VIA_IO_B

    jsr io_clear_put_stack
    jsr io_clear_get_stack

    ; We use acia for I/O
    jsr io_push_put_byte
    .addr acia_put_byte
    jsr io_push_get_byte
    .addr acia_get_byte

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
    def_cmd_handler mdump, cmd_mdump
    def_cmd_handler run, cmd_run
    .byte 0 ; end of table

.code
parse_cmd:
    jsr io_put_const_string
    .asciiz "\r\n"

@prompt:
    lda #PROMPT
    jsr acia_put_byte

    lda #VIA_LED_GREEN
    sta VIA_IO_B

    ldx #0 ; points to address to store next char to be read
@get_byte:
    jsr io_get_byte
    bcs @comm_error
    cmp #$0d            ; line feed?
    beq @got_cmd        ; yes, command was entered
    cmp #$08            ; backspace?
    beq @backspace
    cpx #.sizeof(CMD_BUFFER) ; reached end of buffer space?
    beq @buffer_overflow     ; yes, show error
    sta CMD_BUFFER,x    ; no, append character to buffer
    jsr acia_put_byte   ; echo it back
    inx                 ; bump next address
    bra @get_byte

@buffer_overflow:
    jsr io_put_const_string
    .asciiz "\r\ncommand too large\r\n"
    bra @prompt

@comm_error:
    jsr io_put_const_string
    .asciiz "\r\ncommunication error\r\n"
    bra @prompt

@backspace:
    cpx #0
    beq @get_byte
    dex
    jsr io_put_const_string
    .asciiz "\x08 \x08"
    bra @get_byte

@got_cmd:
    cpx #0              ; user only pressed ENTER (no command)?
    bne @process_cmd    ; no, process the command
    
    ; yes, use the previous command.
    ; write it out as if the user had typed it
@print_cmd:
    lda CMD_BUFFER,x
    cmp #0
    beq @process_cmd
    jsr io_put_byte    
    inx
    bra @print_cmd

@process_cmd:
    stz CMD_BUFFER,x ; NUL marks end of buffer

    jsr io_put_const_string
    .asciiz "\r\n"

    ; Now let's compare the cmd string against the commands we define

    ; our pointer to the character to be returned by item_get_byte
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

    lda #<item_get_byte
    sta strlist_cb_get_byte
    lda #>item_get_byte
    sta strlist_cb_get_byte+1

    jsr process_strlist
    rts

item_get_byte:
    jsr cmdline_get_byte
    cmp #' '    ; space marks the end of the command, the rest is parameters
    bne @ret
    lda #0
@ret:
    clc
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

    jsr io_put_const_string
    .asciiz "invalid command\r\n"
    rts

