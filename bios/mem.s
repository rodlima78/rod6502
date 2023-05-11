.include "mem.inc"
.include "io.inc"
.include "sys.inc"

.export init_mem
.export fill_mem

S = $0100

.segment "HEAP"
.align 2
heap_head: .res 0

.zeropage
ptr: .res 2
len: .res 2

.code
; ================================================================
; X: zp pointer to word where address will be written to
; Y: zp pointer to word w/ allocation size
; thrashed: a,x,y
;
; Pseudo-code:
; bool align2 = size%2==0;
; size += align2 ? 2 : 3;
; byte *next;
; int segsize;
; for(ptr = heap_head; ptr != NULL; ptr = *ptr)
; {
;      if(*ptr & 1) // free ?
;      {
;           ptr &= ~1;
;           segsize = next-ptr;
;           if(segsize >= size)
;           {
;               break;
;           }
;      }
; }
; assert(ptr != NULL);
; output = ptr+2;
; next = *ptr;
; if(segsize != size)
; {
;     // create empty segment following current one till next segment
;     *ptr = ptr+size
;     ptr += size;
;     *ptr = next;
; }
; else
; {
;     *ptr &= ~1;
; }
; size -= align2 ? 2 : 3;
sys_malloc:
    ; Make sure we're aligned to 2 bytes -------------------------
    ; size += size%2==0 ? 2 : 3 
    lda 0,y
    eor #1   ; flips bit0
    lsr      ; C==0 ? align==1, or else, align==2
    php      ; save alignment info in carry for later retrieval
    lda #2
    bcs @is_aligned
    inc
@is_aligned:
    clc
    adc 0,y  ; LSB+2+~Carry (align==1, add 3, or else add 2)
    sta 0,y
    bcc @skip_msb
    lda #0
    adc 1,y  ; increment size MSB (as C==1)
    sta 1,y
@skip_msb:

    phy      ; push pointer to size
    phx      ; push pointer to output
    SIZE   = S+2
    tsx

    ; Loop through linked list of segments until we find one that
    ; has size greater of equal than what's needed

    ; for(ptr = heap_head;
    lda #>heap_head ; ptr points at first segment
    sta ptr+1
    lda #<heap_head
    sta ptr

    ldy #1          ; loop invariant
@loop:
    ; if(*ptr & 1)
    lda (ptr)       ; load LSB of pointer to next segment (+ utilization flag on bit0) 
    lsr             
    bcs @found_free ; C==1 (bit0==1)? yes, found free segment
    ; else
    asl
    pha             ; push LSB
@loop_next:         ; expects LSB w/o flag on stack (expects y==1)
    ; ptr = *ptr
    lda (ptr),y     ; read MSB
    sta ptr+1       ; now we can change ptr, save MSB
    pla             ; pop LSB
    sta ptr         ; save LSB (we know bit0==0)
    bra @loop
@found_free:
    ; test if end of heap
    ; if ptr != NULL
    ; we know A == LSB>>1 of next address
    bne @test_size  ; LSB not zero? go on test seg size
    lda (ptr),y     ; LSB is zero, load up MSB now (we know y==1)
    bne @test_size  ; not zero? go see it it fits
    ; error, end of heap -----------
    jsr sys_abort
    .asciiz "ENOMEM"

@test_size:
    ; calculate size of current segment
    lda (ptr)       ; next seg LSB
    and #.lobyte(~1); make sure LSB don't have the utilization flag set
    pha             ;
    sbc ptr         ; we know C==1, no need for sec
    lda (ptr),y     ; we know y==1
    sbc ptr+1       ; we only need the carry for sbc on MSB
    ldy SIZE,x
    cmp 1,y         ; seg len MSB < needed len MSB?
    bcc @prepare_loop_next  ; yes, segment too small, try next one
    bne @found_fits ; seg len MSB > needed len MSB? yes, it fits
    pla             ; restore next seg LSB
    pha             ; still needs to be on stack for @loop_next
    sbc ptr         ; we know C==1, no need for sec
    cmp 0,y         ; seg len LSB < needed len LSB?
@prepare_loop_next:
    php
    ldy #1          ; restore loop invariant
    plp
    bcc @loop_next  ; yes, seg too small, try next one
@found_fits:        ; found segment large enough!
    ; if(segsize != size)
    bne @create_new_seg
    ; *ptr &= ~1
    lda (ptr)
    and #.lobyte(~1) ; mark segment as being occuppied
    sta (ptr)

@create_new_seg:
    pla             ; restore stack

    ; output = ptr+2 (skip header)
    lda ptr
    clc
    adc #2
    plx             ; restore ptr to output
    sta 0,x
    lda #0
    adc ptr+1
    sta 1,x

    plx     ; pop pointer to size

    lda (ptr)
    lsr         ; current segment is ocuppied (because segsize==size),
    bcc @end    ; don't create new segment, go straight to end

    ; Save values that we'll write to the header of the new empty segment
    ; next = *ptr
    ldy #1
    lda (ptr),y
    pha
    lda (ptr) ; bit0==1 as it's freed
    pha

    ; note: 0,x currently points to len+2, exactly what we need
    ; and make cur seg point to next we'll create
    ; *ptr = ptr+size
    clc
    lda ptr       
    adc 0,x
    pha         ; save LSB
    lda ptr+1
    adc 1,x
    ldy #1
    sta (ptr),y ; we know y==1
    tay         ; save MSB
    pla         
    sta (ptr)
    ; ptr += size
    sta ptr
    sty ptr+1

    ; create header of new (empty) segment
    ; *ptr = next
    pla             ; restore LSB of the old next segment
    sta (ptr)       ; we know bit0==1
    pla
    ldy #1
    sta (ptr),y

@end:
    ; size -= align2 ? 2 : 3
    plp         ; restore alignment
    lda 0,x
    sbc #2      ; C==0? size-3 : size-2
    sta 0,x
    bcs @skip_msb2
    lda 1,x
    dea
    sta 1,x
@skip_msb2:
    clc     ; success
    rts

; ================================================================
; x: zp pointer to word with address to be freed
; thrashed: a, input pointer
sys_free:
    ; do nothing is pointer is null
    lda 0,x
    bne @continue
    lda 1,x
    beq @end
@continue:
    ; make input point to header of segment (ptr-2)
    lda 0,x
    sec
    sbc #2
    sta 0,x
    bcs @skip_msb
    lda 1,x
    dea
    sta 1,x
@skip_msb:
    ; mark it as free
    lda (0,x)
    ora #1
    sta (0,x)
@end:
    stz 0,x
    stz 1,x
    clc
    rts

; ================================================================
; input: X: zp pointer buffer to be filled
;        Y: zp pointer to 16-bit buffer length
;        A: fill byte
fill_mem:
    pha     ; push fill byte
    ; load up addr
    lda 0,x
    sta ptr
    lda 1,x
    sta ptr+1

    pla     ; pop fill byte
    phx     ; push zp pointer to buffer
    tax     ; X -> fill byte

    ; save addr on stack, to be restored later
    lda ptr+1
    pha
    lda ptr
    pha

    ; load up len, also saving it on stack, to be restored later
    lda 1,y
    pha
    sta len+1
    lda 0,y
    pha
    sta len

@loop:
    ; exit loop when len==0
    lda len
    bne @skip_len_msb
    lda len+1
    beq @end
    ; decrement len
    dec len+1
@skip_len_msb:
    dec len
    ; fill in memory
    txa
    sta (ptr)
    ; increment bbase for next byte to be zeroed out
    inc ptr
    bne @skip_base_msb
    inc ptr+1
@skip_base_msb:
    bra @loop
@end:

    ; restore len
    pla
    sta 0,y
    pla
    sta 1,y

    ; get the pointer to addr directly from stack (jump over addr on stack)
    tsx
    lda $0100+3,x
    tax

    ; restore addr
    pla
    sta 0,x
    pla
    sta 1,x

    plx ; restore stack

    rts

; ================================================================
init_mem:
    pha

    ; zero out data segment
    lda #<__DATA_RUN__
    sta ptr
    lda #>__DATA_RUN__
    sta ptr+1
    ldx #ptr

    lda #<__DATA_SIZE__
    sta len
    lda #>__DATA_SIZE__
    sta len+1
    ldy #len
    lda #0
    jsr fill_mem

    LAST_SEG_ADDR = __RAM_START__+__RAM_SIZE__-2

    ; fill in header of first segment
    ; write 16bit pointer to next segment.
    lda #<LAST_SEG_ADDR
    ora #1      ; mark it as not used
    sta heap_head
    lda #>LAST_SEG_ADDR
    sta heap_head+1

    ; define end of heap, pointer to NULL
    lda #1 ; mark it as not used, it helps in the loop in sys_malloc
    sta LAST_SEG_ADDR
    stz LAST_SEG_ADDR+1

    pla
    rts

