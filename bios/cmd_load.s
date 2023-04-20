.include "cmd.inc"
.include "acia.inc"
.include "mem.inc"

.importzp app_loaded

SOH = $01
EOT = $04
ACK = $06
NAK = $15
CAN = $18

.zeropage
next_block: .res 1
next_data_in_block: .res 1 ; index of next data to be read in block

checksum: .res 1
dest_addr: .res 2
retries: .res 1

; o65 header data
seg_align: .res 1
load_flags: .res 1 ; CPU(7),reloc(6),size(5),obj(4),simple(3),chain(2),bsszero(1)
tbase: .res 2 ; original text base address
tlen:  .res 2 ; text length
dbase: .res 2 ; original data base address
dlen:  .res 2 ; data length
bbase: .res 2 ; original bss base address
blen:  .res 2 ; bss length
zbase: .res 2 ; original zeropage base address
zlen:  .res 2 ; zeropage length
slen:  .res 2 ; stack length

dest_tbase: .res 2
dest_dbase: .res 2
dest_bbase: .res 2

STATE_HEADER  = 0
STATE_TEXTSEG = 1
STATE_DATASEG = 2
STATE_IMPORTS = 3
STATE_TEXTREL = 4
STATE_DATAREL = 5
STATE_EXPORTS = 6
STATE_IGNORE = 7
parse_state: .res 1

; ref: http://moscova.inria.fr/~doligez/zmodem/ymodem.txt pg. 20
; ref: http://www.6502.org/users/andre/o65/fileformat.html

.code
cmd_load:
    jsr acia_put_const_string
    .asciiz "Please initiate transfer..."

    ; signal that app is NOT loaded
    stz app_loaded

    lda #1 ; next block number == 1
    sta next_block

    ; 10 retries
    lda #10
    stz retries

    ; start parsing the header
    lda #STATE_HEADER
    sta parse_state

    ; signal sender to start transfer
    lda #NAK
    jsr acia_put_char

start_block:
    ; start receiving block
    lda #10           ; 10s timeout
    jsr acia_get_char ; get start-of-header or end-of-transfer
    bne @error
    cmp #EOT            ; end of transfer?
    beq @file_received  ; yes, we're good
    cmp #SOH            ; no, is it start of header?
    bne @error    ; no? error

    lda #1             ; 1s timeout
    jsr acia_get_char ; block number
    bne @error
    cmp next_block    ; not what we expect?
    bne @error

    lda #1             ; 1s timeout
    jsr acia_get_char ; 255 - block number
    bne @error
    clc
    adc next_block    ; (block_number + (255-block_number))%256 == 255
    cmp #255
    bne @error

    lda #0 ; for updating checksum, start with 0
    sta checksum

    stz next_data_in_block ; next byte read will have index 0

.rodata
@jump_table:
    .addr parse_header
    .addr parse_textseg
    .addr parse_dataseg
    .addr parse_imports
    .addr parse_textrel
    .addr parse_datarel
    .addr parse_exports
    .addr parse_ignore
.code
    lda parse_state
    asl ; *2, to index into the jump table
    tax
    ; emulate an indirect jsr
    lda #>@after_parse     ; MSB 
    pha
    lda #(<@after_parse-1) ; LSB, address point to last byte of jmp insn
    pha
    jmp (@jump_table,x)
@after_parse:
    bne @error

    lda #1             ; 1s timeout
    jsr acia_get_char ; yes, get checksum
    bne @error
    cmp checksum
    bne @error

    ; acknowledge that we have received the block
    lda #ACK
    jsr acia_put_char

    inc next_block

    ; dest_addr points to where next block will be written to
    lda #128
    clc 
    adc dest_addr
    sta dest_addr
    bcc @skip_high
    inc dest_addr+1
@skip_high:
    bra start_block

@error:
    lda #NAK
    jsr acia_put_char

    dec retries      ; still more retries?
    bne start_block ; yes, try it once again   

    jsr acia_purge   ; no, empty recv channel
    jsr acia_put_const_string
    .asciiz " FAILED\r\n"
    jmp cmd_loop

@file_received:
    ; acknowledge that we have received the file
    lda #ACK
    jsr acia_put_char

    jsr acia_put_const_string
    .asciiz " OK\r\n"
    
    ; signal that app is now loaded
    lda #$FF
    sta app_loaded

    jmp cmd_loop

; return a: byte read
read_byte:
    ; would read past end of block?
    lda next_data_in_block
    cmp #128
    beq @error

    lda #1             ; 1s timeout
    jsr acia_get_char
    bne @error

    inc next_data_in_block

    ; update checksum
    pha 
    clc
    adc checksum
    sta checksum
    pla
    rts
@error:
    ; skip block processing and go straight to processing of block's footer 
    pla
    pla
    lda #1  ; signal error
    rts

parse_header:
    ; read magic -------------
.rodata
@marker: .byte $01,$00
@magic:  .byte "o65"
@version: .byte 0
.code
    ldy #0
@loop_magic:
    jsr read_byte
    cmp @marker,y
    bne @error
    iny
    cpy #(.sizeof(@marker)+.sizeof(@magic)+.sizeof(@version))
    bne @loop_magic

    ; read mode LSB -------------
    jsr read_byte
    ; process cpu2 field
    pha
    and #$F0 ; leave only cpu2 field
    cmp #$30 ; is it 6502 (0), 65C02 (1) or 65SC02 (2)?
    bcc @cpu_ok
    pla
    bra @error
@cpu_ok:
    pla

    ; process align field
    and #%11 ; leave only align field
.rodata
@align_values: .byte 0,1,3,255 ; align-1
.code
    tax
    lda @align_values,x
    ina
    sta seg_align

    ; read mode MSB -------------
    jsr read_byte
    sta load_flags      ; save flags
    and #%10110100      ; CPU=6502(0),size=16bit(0),obj=exec(0),chain=no(0)
    bne @error

    ; read segment info (tbase, tlen, dbase, dlen, bbase, blen, zbase, zlen, slen) ---
    ldx #0
@loop_seginfo:
    jsr read_byte
    sta tbase,x
    inx
    cpx #18
    bne @loop_seginfo

    ; allocate memory for the segments
    ldx #tlen
    ldy #dest_tbase
    jsr sys_malloc
    bne @error

    ldx #dlen
    ldy #dest_dbase
    jsr sys_malloc
    bne @error

    ldx #blen
    ldy #dest_bbase
    jsr sys_malloc
    bne @error

    ; read header options (ignore them) ---------------
@read_header_option:
    jsr read_byte
    beq @end_header     ; olen==0? end of optional options
    dea                 ; olen includes 'olen' and 'otype', but the former was read already
    tax
@loop_header_option:
    jsr read_byte       ; ignore data
    dex
    bne @loop_header_option
    bra @read_header_option ; go read next header option

@end_header:

    ; Start processing the text segment, it must be in the same block as header,
    ; headers must not be that long...
    lda #STATE_TEXTSEG
    sta parse_state

    ; go straight to parse_text using tail optimization
    bra parse_textseg

@error:
    lda #1  ; signal error
    rts

parse_textseg:
    lda next_data_in_block 
    cmp #128      ; reached end of block?
    bne @check_end_seg ; no, test if segment is empty
    lda #0            ; yes, done!
    rts

@check_end_seg:
    lda tlen      ; reached end of segment?
    bne @read_seg ; no, seg not empty yet, read it
    lda tlen+1
    bne @read_seg ; no, seg not empty yet, read it

    lda #STATE_DATASEG  ; yes, go to next state
    sta parse_state
    bra parse_dataseg   ; tail optimization

@read_seg:
    jsr read_byte
    sta (dest_tbase)
    ; increment base
    inc dest_tbase
    bne @skip_base_msb
    inc dest_tbase+1
@skip_base_msb:
    ; decrement len
    lda tlen
    bne @skip_len_msb
    dec tlen+1
@skip_len_msb:
    dec tlen
    bra parse_textseg

parse_dataseg:
    lda next_data_in_block 
    cmp #128      ; reached end of block?
    bne @check_end_seg ; no, test if segment is empty
    lda #0            ; yes, done!
    rts

; reached end of segment?
@check_end_seg:
    lda dlen
    bne @read_seg ; no, seg not empty yet, read it
    lda dlen+1
    bne @read_seg ; no, seg not empty yet, read it

    lda #STATE_IGNORE  ; yes, go to next state
    sta parse_state
    bra parse_ignore   ; tail optimization

@read_seg:
    jsr read_byte
    sta (dest_dbase)
    ; increment base
    inc dest_dbase
    bne @skip_base_msb
    inc dest_dbase+1
@skip_base_msb:
    ; decrement len
    lda dlen
    bne @skip_len_msb
    dec dlen+1
@skip_len_msb:
    dec dlen
    bra parse_dataseg

parse_imports:
parse_textrel:
parse_datarel:
parse_exports:

parse_ignore:
    lda next_data_in_block 
    cmp #128      ; reached end of block?
    bne @more_data

    lda #0
    rts

@more_data:
    jsr read_byte
    bra parse_ignore
