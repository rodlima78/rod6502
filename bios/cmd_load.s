.include "cmd.inc"
.include "acia.inc"
.include "mem.inc"
.include "xmodem.inc"
.include "lcd.inc"

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

; ref: http://www.6502.org/users/andre/o65/fileformat.html

.code
cmd_load:
    jsr acia_put_const_string
    .asciiz "Please initiate transfer..."

    ldx #<load_error
    ldy #>load_error
    jsr xmodem_init

    ; 1. process header ---------------------------
    ; read magic
.rodata
@marker: .byte $01,$00
@magic:  .byte "o65"
@version: .byte 0
.code
    ldy #0
@loop_magic:
    jsr xmodem_read_byte
    cmp @marker,y
    bne load_error
    iny
    cpy #(.sizeof(@marker)+.sizeof(@magic)+.sizeof(@version))
    bne @loop_magic

    ; read mode LSB
    jsr xmodem_read_byte
    ; process cpu2 field
    pha
    and #$F0 ; leave only cpu2 field
    cmp #$30 ; is it 6502 (0), 65C02 (1) or 65SC02 (2)?
    bcc @cpu_ok
    pla
    bra load_error
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
    jsr xmodem_read_byte
    sta load_flags      ; save flags
    and #%10110100      ; CPU=6502(0),size=16bit(0),obj=exec(0),chain=no(0)
    bne load_error

    ; read segment info (tbase, tlen, dbase, dlen, bbase, blen, zbase, zlen, slen) ---
    ldx #0
@loop_seginfo:
    jsr xmodem_read_byte
    sta tbase,x
    inx
    cpx #18
    bne @loop_seginfo

    ; allocate memory for the segments
    ldx #tlen
    ldy #dest_tbase
    jsr sys_malloc
    bne load_error

    ldx #dlen
    ldy #dest_dbase
    jsr sys_malloc
    bne load_error

    ldx #blen
    ldy #dest_bbase
    jsr sys_malloc
    bne load_error

    ; read header options (ignore them)
@read_header_option:
    jsr xmodem_read_byte
    beq @end_header_options  ; olen==0? end of optional options
    dea                      ; olen includes 'olen' and 'otype', but the former was read already
    tax
@loop_header_option:
    jsr xmodem_read_byte       ; ignore data
    dex
    bne @loop_header_option
    bra @read_header_option ; go read next header option
@end_header_options:

    ; 2. read text segment --------------------------------------
read_textseg:
    lda tlen      ; reached end of segment?
    bne @read_seg ; no, seg not empty yet, read it
    lda tlen+1
    bne @read_seg ; no, seg not empty yet, read it

    bra read_dataseg

@read_seg:
    jsr xmodem_read_byte
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
    bra read_textseg

load_error:
    jsr xmodem_deinit
    jmp cmd_loop

    ; 3. read data segment --------------------------------------
read_dataseg:
    lda dlen
    bne @read_seg ; no, seg not empty yet, read it
    lda dlen+1
    bne @read_seg ; no, seg not empty yet, read it

    bra read_ignore

@read_seg:
    jsr xmodem_read_byte
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
    bra read_dataseg

    ; 4. ignore remaining data --------------------------------------
read_ignore:
    jsr xmodem_skip_block
    beq read_ignore

    ; 5. if requested, zero out BSS ------------------
    lda #%10
    bit load_flags
    beq @skip_zero_bss
    jsr zero_bss

@skip_zero_bss:
    jsr acia_put_const_string
    .asciiz " OK"
    
    ; signal that app is now loaded
    lda #$FF
    sta app_loaded

    jsr xmodem_deinit

    jmp cmd_loop

zero_bss:
    pha
@loop:
    ; exit loop when blen==0
    lda blen
    bne @skip_blen_msb
    lda blen+1
    beq @end
    ; decrement blen
    dec blen+1
@skip_blen_msb:
    dec blen
    ; zero out memory
    lda #0
    sta (dest_bbase)
    ; increment bbase for next byte to be zeroed out
    inc dest_bbase
    bne @skip_bbase_msb
    inc dest_bbase+1
@skip_bbase_msb:
    bra @loop
@end:
    pla
    rts

