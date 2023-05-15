.include "mem.inc"
.include "io.inc"
.include "sys.inc"

.export init_mem
.export fill_mem

S = $0100

.segment "HEAP"
.align 2
heap_free: .res 0

.zeropage
ptr:   .res 2
pfree: .res 2
len:   .res 2

.code
; ================================================================
; X: zp pointer to word where address will be written to
; Y: zp pointer to word w/ allocation size
; thrashed: a,x,y
;
; Pseudo-code --------------------------------------
; bool align2 = size%2==0;
; size += align2 ? 2 : 3;
; int segsize;
; void *ptr = heap_free;
; void *pfree = NULL;
; do
; {
;      if(*ptr & 1) // free ?
;      {
;           if(pfree == NULL)
;           {
;               pfree = ptr;
;           }
;           ptr = *ptr & ~1;
;           assert(ptr != NULL);
;           segsize = ptr-pfree;
;           if(segsize >= size)
;           {
;               break;
;           }
;           // is next seg occupied?
;           if((*ptr & 1) == 0)
;           {
;               // have to look for another free seg
;               pfree = NULL;
;           }
;      }
;      else
;      { 
;           ptr = *ptr;
;      }
; }
; while(ptr != NULL);
; output = pfree+2;
; if(segsize != size)
; {
;     // create empty segment following current one till ptr segment
;     *pfree = pfree+size // returned segment will be marked as occupied
;     pfree += size;      // pfree points to added empty segment
;     ptr |= 1;           // mark new segment as being free during assignment below
; }
; *pfree = ptr;
;
; size -= align2 ? 2 : 3;
; -------------------------------------------
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
    adc 0,y  ; LSB+(align==10 2: 3)
    sta 0,y
    bcc @skip_msb
    lda #0
    adc 1,y  ; increment size MSB (as C==1)
    sta 1,y
@skip_msb:
    phy      ; push pointer to size
    phx      ; push pointer to output
    OUTPUT = S+1
    SIZE   = S+2
    tsx      ; X = pointer to local stack

    ; void *pfree = NULL; (we indicate it with 1 (odd) on LFS, as all valid addresses are even.
    lda #1
    sta pfree

    ; Loop through linked list of segments until we find one that
    ; has size greater of equal than what's needed

    ; ptr = heap_free;
    lda #>heap_free ; ptr points at first free segment
    sta ptr+1
    lda #<heap_free
    sta ptr

    ldy #1          ; loop invariant
@loop:
    ; if(*ptr & 1)
    lda (ptr)       ; load LSB of pointer to next segment (+ utilization flag on bit0) 
    lsr             
    bcs @found_free ; C==1 (bit0==1)? yes, found free segment
    ; else
    asl
    pha
    ; ptr = *ptr
    lda (ptr),y     ; read MSB, we know y==1
    sta ptr+1       ; now we can change ptr, save MSB
    pla
    sta ptr         ; save LSB (we know bit0==0)
    bra @loop
@found_free:
    ; test if end of heap
    ; assert(ptr != NULL)
    ; we know A == LSB>>1 of next address
    bne @test_size  ; LSB not zero? go on test seg size
    lda (ptr),y     ; LSB is zero, load up MSB now (we know y==1)
    bne @test_size  ; not zero? go see it it fits
    ; error, end of heap -----------
    jsr sys_abort
    .asciiz "ENOMEM"

@test_size:
    ; if(pfree == NULL)
    lda pfree
    lsr
    bcc @after_assign_pfree
    ; pfree = ptr;
    lda ptr
    sta pfree
    lda ptr+1
    sta pfree+1
@after_assign_pfree:
    ; ptr = *ptr & ~1
    lda (ptr)
    and #<~1
    pha
    lda (ptr),y     ; we know y==1
    sta ptr+1
    pla
    sta ptr
    ; segsize = ptr-pfree
    sec
    sbc pfree
    lda ptr+1
    sbc pfree+1
    ldy SIZE,x
    ; if(segsize >= size)
    cmp 1,y         ; seg len MSB < needed len MSB?
    bcc @prepare_loop_next  ; yes, segment too small, try next one
    bne @found_fits ; seg len MSB > needed len MSB? yes, it fits
    lda ptr
    sbc pfree       ; we know C==1, no need for sec
    cmp 0,y         ; seg len LSB >= needed len LSB?
    bcs @found_fits ; it fits, exit loop
@prepare_loop_next:
    ldy #1          ; restore loop invariant
    ; if((*ptr & 1) == 0)
    lda (ptr)
    lsr
    bcs @loop
    ; pfree = NULL
    sty pfree       ; we know y==1
    bra @loop       ; yes, seg too small, try next one
@found_fits:        ; found segment large enough!
    php             ; push segsize==size
    ; output = pfree+2 (skip header)
    lda pfree
    clc
    adc #2
    ldy OUTPUT,x
    sta 0,y
    lda pfree+1
    adc #0
    sta 1,y

    plp             ; pop segsize==size
    beq @end        ; segsize==size? go to end

    ; *pfree = pfree+size
    clc
    ldy SIZE,x
    lda 0,y
    adc pfree
    pha
    lda 1,y
    adc pfree+1
    ldy #1
    sta (pfree),y
    tay
    pla
    sta (pfree)
    ; pfree += size
    sta pfree
    tya
    sta pfree+1
    ; ptr |= 1
    lda ptr
    ora #1
    sta ptr

@end:
    ; *pfree = ptr
    lda ptr
    sta (pfree)
    lda ptr+1
    ldy #1
    sta (pfree),y

    pla     ; pop pointer to output, not needed anymore
    plx     ; pop pointer to size

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
    ora #1      ; mark it as free
    sta heap_free
    lda #>LAST_SEG_ADDR
    sta heap_free+1

    ; define end of heap, pointer to NULL
    lda #1 ; mark it as free, it helps in the loop in sys_malloc
    sta LAST_SEG_ADDR
    stz LAST_SEG_ADDR+1

    pla
    rts

