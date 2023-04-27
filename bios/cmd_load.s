.include "cmd.inc"
.include "acia.inc"
.include "mem.inc"
.include "xmodem.inc"
.include "lcd.inc"
.include "sys.inc"

.importzp app_loaded
.import import_table

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

ptr: .res 2

dest_tbase: .res 2
dest_dbase: .res 2
dest_bbase: .res 2

num_imports: .res 2
dest_imports: .res 2
cur_src_import: .res 2
cur_dst_import: .res 2

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
    beq @magic_ok
    jmp load_error
@magic_ok:
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
    lda dest_tbase
    sta ptr
    lda dest_tbase+1
    sta ptr+1

@copy_byte:
    lda tlen      ; reached end of segment?
    bne @read_seg ; no, seg not empty yet, read it
    lda tlen+1
    bne @read_seg ; no, seg not empty yet, read it

    bra read_dataseg

@read_seg:
    jsr xmodem_read_byte
    sta (ptr)
    ; increment base
    inc ptr
    bne @skip_base_msb
    inc ptr+1
@skip_base_msb:
    ; decrement len
    lda tlen
    bne @skip_len_msb
    dec tlen+1
@skip_len_msb:
    dec tlen
    bra @copy_byte

load_error:
    jsr xmodem_deinit
    jmp cmd_loop

    ; 3. read data segment --------------------------------------
read_dataseg:
    lda dest_dbase
    sta ptr
    lda dest_dbase+1
    sta ptr+1

@copy_byte:
    lda dlen
    bne @read_seg ; no, seg not empty yet, read it
    lda dlen+1
    bne @read_seg ; no, seg not empty yet, read it

    bra read_imports

@read_seg:
    jsr xmodem_read_byte
    sta (ptr)
    ; increment base
    inc ptr
    bne @skip_base_msb
    inc ptr+1
@skip_base_msb:
    ; decrement len
    lda dlen
    bne @skip_len_msb
    dec dlen+1
@skip_len_msb:
    dec dlen
    bra @copy_byte

    ; 4. parse import list --------------------------------------
read_imports:
    jsr xmodem_read_byte
    sta num_imports
    jsr xmodem_read_byte
    sta num_imports+1

    ; allocate memory for the import address mapping
    ldx #num_imports
    ldy #dest_imports
    jsr sys_malloc
    bne load_error
    ; allocate twice the size, as each import slot holds one address (2 bytes)
    ; Note: assuming allocation is contiguous w/ previous block.
    ldy #cur_dst_import ; dummy
    jsr sys_malloc
    bne load_error

    ; start filling up first import
    lda dest_imports
    sta cur_dst_import
    lda dest_imports+1
    sta cur_dst_import+1

@read_next_import:
    ; exit loop when num_imports==0
    lda num_imports
    bne @skip_msb3
    lda num_imports+1
    beq @end
    ; decrement number of imports to be read
    dec num_imports+1
@skip_msb3:
    dec num_imports

    ; start search from first item of import table
    lda #<import_table    
    sta cur_src_import
    lda #>import_table
    sta cur_src_import+1

    ldy #1  ; point to first character
@find_newchar:
    jsr xmodem_read_byte
@find_char:
    cmp (cur_src_import),y
    bcc load_error       ; query < import ? not found
    bne @try_next_import ; query > import ? try next
    cmp #0               ; query == import, end of string? 
    beq @found           ; yes, found it!
    iny                  ; no, compare next char
    bra @find_newchar

@try_next_import:
    pha                  ; save query char
    ; increment cur_src_import
    lda (cur_src_import) ; load stride
    clc
    adc cur_src_import   ; make cur_src_import point to next import
    sta cur_src_import
    bcc @skip_msb
    inc cur_src_import+1
@skip_msb:
    pla             ; restore query char
    bra @find_char

@found:
    ; Save the import address to the dst import table
    iny
    lda (cur_src_import),y
    sta (cur_dst_import)
    iny
    lda (cur_src_import),y
    ldy #1               ; we don't need y anymore, this is ok
    sta (cur_dst_import),y

    ; increment dest pointer
    lda #2               ; import slot has 2 bytes
    clc
    adc cur_dst_import
    sta cur_dst_import
    bcc @skip_msb4
    inc cur_dst_import+1
@skip_msb4:
    bra @read_next_import

@end:

    ; 5. ignore remaining data --------------------------------------
read_ignore:
    jsr xmodem_skip_block
    beq read_ignore
    
    ; 6. if requested, zero out BSS ------------------
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
    lda dest_bbase
    sta ptr
    lda dest_bbase+1
    sta ptr+1

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
    sta (ptr)
    ; increment bbase for next byte to be zeroed out
    inc ptr
    bne @skip_bbase_msb
    inc ptr+1
@skip_bbase_msb:
    bra @loop
@end:
    pla
    rts

