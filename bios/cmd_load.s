.include "cmd.inc"
.include "acia.inc"
.include "mem.inc"
.include "xmodem.inc"
.include "sys.inc"
.include "strlist.inc"

.importzp app_loaded
.import import_table
.export save_stack
.export ptr_app_entrypoint

SOH = $01
EOT = $04
ACK = $06
NAK = $15
CAN = $18

.segment "ZPTMP": zeropage
next_block: .res 1
next_data_in_block: .res 1 ; index of next data to be read in block

checksum: .res 1
dest_addr: .res 2
retries: .res 1

; o65 header data
seg_align: .res 1
load_flags: .res 1 ; CPU(7),reloc(6),size(5),obj(4),simple(3),chain(2),bsszero(1),nd(0)
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
len: .res 2

; must have same order as segs in o65 header
dest_tbase: .res 2
dest_dbase: .res 2
dest_bbase: .res 2
dest_zbase: .res 2

dest_imports: .res 2
cur_src_import: .res 2
cur_dst_import: .res 2
cur_rel: .res 2

SEGID_UNDEFINED = 0
SEGID_ABSOLUTE  = 1
SEGID_TEXTSEG   = 2
SEGID_DATASEG   = 3
SEGID_BSS       = 4
SEGID_ZEROPAGE  = 5

TYPE_WORD     = $80 ; 2 byte address
TYPE_HIGH     = $40 ; MSB of an address
TYPE_LOW      = $20 ; LSB of an address
TYPE_SEGADDR  = $C0 ; not used, 65816
TYPE_SEG      = $A0 ; not used, 65816

.data
save_stack: .res 1
ptr_app_entrypoint: .res 2

.rodata
.macro def_global_symbol name, sym
    .byte 1+.strlen(.string(name))+1+2
    .asciiz .string(name)
    .addr sym
.endmacro
app_globals_table:
    ; must be sorted in ascii order
    def_global_symbol main, ptr_app_entrypoint
    .byte 0 ; end-of-table

; ref: http://www.6502.org/users/andre/o65/fileformat.html

.code
cmd_load:
    ; save stack pointer so that we can restore in case of errors
    tsx
    stx save_stack

    ; No entry point defined (so far)
    stz ptr_app_entrypoint
    stz ptr_app_entrypoint+1

    ; app zp starts where bios' ends
    lda #<__ZEROPAGE_SIZE__
    sta dest_zbase
    lda #>__ZEROPAGE_SIZE__
    sta dest_zbase+1

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
    ldx #dest_tbase
    ldy #tlen
    jsr sys_malloc
    bne load_error

    ldx #dest_dbase
    ldy #dlen
    jsr sys_malloc
    bne load_error

    ldx #dest_bbase
    ldy #blen
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
    ldx #dest_tbase
    ldy #tlen
    jsr parse_segdata
    bne load_error
    bra read_dataseg

load_error:
    jsr xmodem_deinit
    ; restore stack pointer
    ldx save_stack
    txs
    jmp cmd_loop

    ; 3. read data segment --------------------------------------
read_dataseg:
    ldx #dest_dbase
    ldy #dlen
    jsr parse_segdata
    bne load_error

    ; 4. parse import list --------------------------------------
read_imports:
    ; receive number of imports to read
    jsr xmodem_read_byte
    sta len
    sta strlist_len
    jsr xmodem_read_byte
    sta len+1
    sta strlist_len+1

    ; allocate memory for the import address mapping
    ldx #dest_imports
    asl len     ; each address is 2 bytes, so use len*2
    rol len+1
    ldy #len
    jsr sys_malloc
    bne load_error

    ; start filling up first import
    lda dest_imports
    sta cur_dst_import
    lda dest_imports+1
    sta cur_dst_import+1

    lda #<import_table
    sta strlist
    lda #>import_table
    sta strlist+1

    lda #<@item_found
    sta strlist_cb_found
    lda #>@item_found
    sta strlist_cb_found+1

    lda #<@item_not_found
    sta strlist_cb_not_found
    lda #>@item_not_found
    sta strlist_cb_not_found+1

    lda #<xmodem_read_byte
    sta strlist_cb_read_byte
    lda #>xmodem_read_byte
    sta strlist_cb_read_byte+1

    jsr process_strlist
    bcs load_error

    bra read_textrel

@item_found:
    ; Save the import address to the dst import table
    lda (strlist_ptr),y
    sta (cur_dst_import)
    iny
    lda (strlist_ptr),y
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
    rts

@item_not_found:
    jmp load_error

    ; 5. do text relocation --------------------------------------
read_textrel:
    ldx #dest_tbase
    jsr read_segrel

    ; 6. do data relocation --------------------------------------
read_datarel:
    ldx #dest_dbase
    jsr read_segrel

    ; 7. read exported globals list ------------------------------
read_exported_globals_list:
    ; receive number of exports to read
    jsr xmodem_read_byte
    sta strlist_len 
    jsr xmodem_read_byte
    sta strlist_len+1

    ; set up the stringlist processing to
    ; find the global exports we understand from
    ; 'app_globals_table', and update their symbol address
    ; with data from o65.
    lda #<app_globals_table
    sta strlist
    lda #>app_globals_table
    sta strlist+1

    lda #<@item_found
    sta strlist_cb_found
    lda #>@item_found
    sta strlist_cb_found+1

    lda #<@item_not_found
    sta strlist_cb_not_found
    lda #>@item_not_found
    sta strlist_cb_not_found+1

    lda #<xmodem_read_byte
    sta strlist_cb_read_byte
    lda #>xmodem_read_byte
    sta strlist_cb_read_byte+1

    jsr process_strlist
    bcs @load_error1
    bra o65_finished

@load_error1:
    jmp load_error

@item_found:
    ; Use our relocation function to write the final symbol addres
    ; to the address in the table
    jsr xmodem_read_byte ; read the segment id
    asl
    tax                  ; X = segID*2, needed by segid_generic

    lsr                  ; back to segID
    ora #$80             ; make it a WORD relocation
    pha                  ; save typebyte|segID

    ; set the address to be relocated
    lda (strlist_ptr),y
    sta cur_rel
    iny
    lda (strlist_ptr),y
    sta cur_rel+1

    ; Initialize it with the src address
    jsr xmodem_read_byte ; read src addr LSB
    sta (cur_rel)        ; save it
    jsr xmodem_read_byte ; read src addr MSB
    ldy #1
    sta (cur_rel),y      ; save it

    pla ; restore typebyte|segID

    cpx #SEGID_ABSOLUTE*2   ; address is absolute? (x==segid*2)
    beq @dont_relocate      ; yes, do not relocate 
    jmp segid_generic       ; no, Relocate the address (tail call optimization)
@dont_relocate:
    rts

@item_not_found:
@loop:
    jsr xmodem_read_byte
    bne @loop  ; read till end of string
    jsr xmodem_read_byte ; swallow segid
    jsr xmodem_read_byte ; swallow addr LSB
    jsr xmodem_read_byte ; swallow addr LSB
    rts ; will process next item

o65_finished:
    jsr xmodem_skip_block
    beq o65_finished   ; skip all remaining blocks
    jsr xmodem_deinit

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

    jmp cmd_loop

; ===============================================
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

; ===============================================
; x: zp ptr to dest seg
read_segrel:
    ; start at tbase
    ldy 1,x
    lda 0,x
    ; decrement it, as relocation starts at base-1
    bne @skip_msb
    dey
@skip_msb:
    dea
    sta cur_rel
    sty cur_rel+1

process_relocation:
    jsr xmodem_read_byte ; get offset byte
    bne @do_reloc      ; not zero ? do relocation
    rts                ; zero? no more relocations
@do_reloc:
    ; add offset byte to cur_rel pointer
    pha
    cmp #255
    bne @add_offset
    dea
@add_offset:
    clc
    adc cur_rel
    sta cur_rel
    bcc @skip_msb
    inc cur_rel+1
@skip_msb:
    pla
    cmp #255               ; byte == 255?
    beq process_relocation ; yes, add next byte

.rodata
segid_jumptable:
    .addr segid_undefined
    .addr segid_absolute
    .addr segid_generic ; text
    .addr segid_generic ; data
    .addr segid_generic ; bss
    .addr segid_generic ; zeropage
.code
    jsr xmodem_read_byte    ; read typebyte|segID
    pha                     ; push it to stack
    and #$0f                ; A=segID
    cmp #6                  ; index < 6?
    bcc @process_segid      ; yes, process segID
    ; no need to restore stack, load_error takes care of it
    jmp load_error          ; no, out of bounds: error
@process_segid:
    asl             ; A = segID*2: index into jumptable
    tax
    pla             ; restore typebyte|segID

    ; emulate indirect jsr, returning to process_relocation
    ldy #>(process_relocation-1)
    phy
    ldy #<(process_relocation-1)
    phy
    jmp (segid_jumptable,x)

segid_undefined:
    pha ; save typebyte|segID

    ; Read symbol index and make cur_dst_import point to its address
    lda dest_imports    ; point to start of import table
    sta cur_dst_import
    lda dest_imports+1
    sta cur_dst_import+1

    ; add index*2 (as table slot size is 2 bytes)
    jsr xmodem_read_byte ; read index LSB
    asl ; *2
    php ; save carry bit
    clc
    adc cur_dst_import  ; add to ptr LSB
    sta cur_dst_import
    bcc @skip_msb
    inc cur_dst_import+1
@skip_msb:
    jsr xmodem_read_byte ; read index MSB
    plp ; restore carry bit from LSB*2
    rol ; *2, and include carry bit from LSB*2
    ; clc must not have carry bit. If set, we'll have unavoidable problems.
    adc cur_dst_import+1
    sta cur_dst_import+1

    lda (cur_dst_import)
    tax
    ldy #1
    lda (cur_dst_import),y
    tay
    pla  ; restore typebyte|segID
    jmp relocate ; tail call optimization

segid_generic:
    pha ; save typebyte|segID
    ; X is segID*2
    txa
    sec
    sbc #4 ; skip undefined and absolute segIDs
    tax ; X: index to dest_base (stride=2, starts at text segID)
    clc
    asl
    tay ; Y: index to base (stride=4, starts at text segID)

    ; offset = dest.base-orig.base
    lda dest_tbase,x
    sec
    sbc tbase,y
    pha  ; save offset LSB
    lda dest_tbase+1,x
    sbc tbase+1,y
    tay  ; assign offset MSB to Y
    pla  ; restore offset LSB
    tax  ; and assign it to X
    pla  ; restore typebyte|segID
    jmp relocate ; tail call optimization

segid_absolute:
    ; don't relocate anything
    bit #TYPE_HIGH
    beq @end
    lda #%1000000      ; page-wise reloc bit
    bit load_flags     ; is it set?
    bne @end           ; no, use bytewire reloc (hot path)
    jsr xmodem_read_byte ; swallow low_byte
@end:
    rts


; ===============================================
; x: zp ptr to dest data seg
; y: zp ptr to seg length
parse_segdata:
    ; load ptr to dest data buffer
    lda 0,x
    sta ptr
    lda 1,x
    sta ptr+1

    ; load ptr to seg length
    lda 1,y
    sta len+1
    lda 0,y
    sta len

@copy_byte:
    lda len      ; reached end of segment?
    bne @read_seg ; no, seg not empty yet, read it
    lda len+1
    bne @read_seg ; no, seg not empty yet, read it

    rts ; OK: Z==1

@read_seg:
    jsr xmodem_read_byte
    sta (ptr)
    ; increment base
    inc ptr
    bne @skip_base_msb
    inc ptr+1
@skip_base_msb:
    ; decrement len
    lda len
    bne @skip_len_msb
    dec len+1
@skip_len_msb:
    dec len
    bra @copy_byte

; ===============================================
; stack: typebyte|segID
; a: typebyte|segID
; y: MSB offset
; x: LSB offset
; cur_rel: pointer to data to be relocated
relocate:
    bit #TYPE_WORD
    bne @type_word
    bit #TYPE_HIGH
    bne @type_high
    bit #TYPE_LOW
    bne @type_low

    jmp load_error

@type_word:
    ; load the word directly from the segment
    ; and add the symbol address to the addr offset
    txa             ; get offset LSB
    clc
    adc (cur_rel)   ; add with data LSB
    sta (cur_rel)   ; store relocated LSB
    tya             ; get offset MSB
    ldy #1
    adc (cur_rel),y ; add with data MSB (and carry of LSB)
    sta (cur_rel),y ; store relocated MSB
    rts

@type_high:
    lda #%1000000        ; page-wise reloc bit
    bit load_flags       ; is it set?
    clc                  ; keep carry reset in case doing page-wise reloc
    bne @_incr_msb       ; yes, use page-wise reloc (cold path)
    jsr xmodem_read_byte ; no, read len_byte (hot path)
    sta len
    txa                  ; get offset LSB
    adc len              ; add it to len_byte, only carry matters
@_incr_msb:
    tya                  ; get offset MSB
    adc (cur_rel)        ; add with data MSB, including carry from LSB
    sta (cur_rel)        ; store relocated MSB
    rts

@type_low:
    txa                  ; get offset LSB
    clc
    adc (cur_rel)        ; add data LSB
    sta (cur_rel)        ; store relocated LSB (do not need MSB)
    rts

