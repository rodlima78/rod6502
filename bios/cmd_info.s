.include "io.inc"
.include "strlist.inc"
.include "cmd.inc"
.include "mem.inc"

.feature string_escapes
.feature loose_char_term

S = $0100

.segment "ZPTMP": zeropage
ptr: .res 2

.rodata
.macro def_cmd_handler name, sym
    .byte 1+.strlen(.string(name))+1+2
    .asciiz .string(name)
    .addr sym
.endmacro
cmd_info_jumptable:
    def_cmd_handler heap, cmd_infoheap
    .byte 0 ; end of table

; =============================================================
cmd_info:
    jsr io_push_get_byte
    .addr cmdline_get_byte
    
    ; just one item
    lda #1
    sta strlist_len
    stz strlist_len+1

    lda #<cmd_info_jumptable
    sta strlist
    lda #>cmd_info_jumptable
    sta strlist+1

    lda #<item_found
    sta strlist_cb_found
    lda #>item_found
    sta strlist_cb_found+1

    lda #<item_not_found
    sta strlist_cb_not_found
    lda #>item_not_found
    sta strlist_cb_not_found+1

    lda #<io_get_byte
    sta strlist_cb_get_byte
    lda #>io_get_byte
    sta strlist_cb_get_byte+1

    jsr process_strlist
    jmp cmd_loop

item_found:
    iny
    lda (strlist_ptr),y 
    pha     ; push addr MSB
    dey
    lda (strlist_ptr),y
    pha     ; push addr LSB
    tsx ; X+1 points to cmd
    jsr @call
    pla
    pla
    rts
@call:
    jmp (S+1,x)

item_not_found:
    jsr io_put_const_string
    .asciiz "invalid syntax\r\n"
    rts

; =============================================================
cmd_infoheap:
    lda #<__HEAP_RUN__
    sta ptr
    lda #>__HEAP_RUN__
    sta ptr+1

@next_segment1:
    lda (ptr)
    lsr
    pha
@next_segment2:
    ; Print whether occupied (*) or not
    bcc @occupied
    lda #' '
    bra @continue
@occupied:
    lda #'*'
@continue:
    jsr io_put_byte

    pla
    asl
    pha             ; push LO_NEXT
    ldy #1
    lda (ptr),y
    pha             ; push HI_NEXT

    ; print memory address from current segment (ptr+2)
    lda #'['
    jsr io_put_byte
    lda #2
    clc
    adc ptr
    tax             ; save LO_MEM in X
    lda ptr+1
    adc #0          ; will increment A if C==1
    pha             ; push HI_MEM
    jsr io_put_hex  ; write it
    txa             ; recover LO_MEM
    pha             ; push LO_MEM
    jsr io_put_hex  ; write it

    lda #'-'
    jsr io_put_byte

    ; stack variables:
    @LO_MEM = S+1
    @HI_MEM = S+2
    @LO_SIZE = @LO_MEM
    @HI_SIZE = @HI_MEM
    @HI_NEXT = S+3
    @LO_NEXT = S+4
    tsx

    ; Calc memory buffer size
    lda @LO_NEXT,x
    tay                 ; Y = LO_NEXT
    sec
    sbc @LO_MEM,x       ; A = LO_NEXT-LO_MEM
    sta @LO_SIZE,x      ; A = LO_SIZE
    lda @HI_NEXT,x   
    sbc @HI_MEM,x       ; A = HI_NEXT-LO_NEXT-adj
    sta @HI_SIZE,x      ; A = HI_SIZE

    ; Write end range (next)
    lda @HI_NEXT,x   
    jsr io_put_hex
    tya
    jsr io_put_hex

    jsr io_put_const_string
    .asciiz ") "

    pla            ; pop LO_SIZE
    tay
    pla            ; pop HI_SIZE
    jsr io_put_hex ; write HI_SIZE
    tya
    jsr io_put_hex ; write LO_SIZE

    jsr io_put_const_string
    .asciiz "\r\n"

    ; make cur = next
    pla             ; pop HI_NEXT
    sta ptr+1
    pla             ; pop LO_NEXT
    sta ptr

    ; reached end of heap?
    ldy #1
    lda (ptr),y
    bne @next_segment1   ; no, go to next
    lda (ptr)
    lsr         
    bne @next_segment2

    rts
