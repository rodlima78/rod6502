.include "lcd.inc"
.include "mem.inc"
.include "io.inc"

.export init_mem
.export fill_mem

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
; ret A: status 0->ok, 1->nomem
sys_malloc:
    ; add 2 (or 3) to allocation size to compensate the fact that the segment
    ; size include its header size (2). Before returning we'll undo this.
    ; If alignment!=2, add 3 instead to keep size multiple of 2.
    lda 0,y
    lsr      ; C==1 ? align==1, or else, align==2
    php      ; save alignment info in carry for later retrieval
    lda #2
    adc 0,y  ; LSB+2+Carry (align==1, add 3, or else add 2)
    sta 0,y
    bcc @skip_msb
    lda #0
    adc 1,y  ; increment it (as C==1)
    sta 1,y
@skip_msb:

    ; Loop through linked list of segments until we find one that
    ; has size greater of equal than what's needed
    lda #>heap_head ; ptr points at first segment
    sta ptr+1
    lda #<heap_head
    sta ptr

    phx     ; save pointer to output address
    tya
    tax     ; now X == pointer to allocation size (so that we can reuse Y)

    ldy #1  ; invariant, needed inside loop
@loop:
    lda (ptr)       ; load LSB of pointer to next segment (+ utilization flag on bit0) 
    lsr             
    bcs @found_free ; C==1 (bit0==1)? yes, found free segment
    asl
    pha             ; push LSB
@loop_next:         ; expects LSB w/o flag on stack
    lda (ptr),y     ; read MSB, we know y==1
    sta ptr+1       ; now we can change ptr, save MSB
    pla             ; pop LSB
    sta ptr         ; save LSB (we know bit0==0)
    bra @loop
@found_free:
    ; test if end of heap
    ; we know A == LSB>>1 of next address
    bne @test_size  ; LSB not zero? go on test seg size
    lda (ptr),y     ; LSB is zero, load up MSB now (we know y==1)
    beq @error      ; it's zero? error, end of heap
@test_size:
    ; calculate size of current segment
    lda (ptr)       ; next seg LSB
    and #.lobyte(~1); make sure LSB don't have the utilization flag set
    pha             ; @loop_next needs next seg's LSB on top of stack
    sbc ptr         ; we know C==1, no need for sec
    lda (ptr),y     ; we know y==1
    sbc ptr+1       ; we only need the carry for sbc on MSB
    cmp 1,x         ; seg len MSB < needed len MSB?
    bcc @loop_next  ; yes, segment too small, try next one
    bne @found_fits ; seg len MSB > needed len MSB? yes, it fits
    pla             ; restore LSB
    pha             ; still needs to be on stack for @loop_next
    sbc ptr         ; we know C==1, no need for sec
    cmp 0,x         ; seg len LSB < needed len LSB?
    bcc @loop_next  ; yes, seg too small, try next one
@found_fits:        ; found segment large enough!
    pla             ; restore stack
    ply             ; restore ptr to output address

    ; return ptr+2 (skipping header)
    lda ptr
    clc
    adc #2
    sta 0,y
    lda #0
    adc ptr+1
    sta 1,y

    ; Y is now free for reuse

    ; Now we update the segment to indicate it's being used and create new empty segment -------

    ; save values that we'll write to the header of the new empty segment
    ldy #1
    lda (ptr),y
    pha
    lda (ptr) ; bit0==1 as it's freed
    pha

    ; mark segment as being occupied
    and #.lobyte(~1) 
    sta (ptr)

    ; make ptr point one past end of current segment (beginning of the new empty seg)
    ; note: x currently points to len+2, exactly what we need
    ; and make cur seg point to next we'll create
    clc
    lda ptr       
    adc 0,x
    pha
    lda ptr+1
    adc 1,x
    sta (ptr),y
    tay
    pla
    sta (ptr)
    sta ptr
    sty ptr+1
    
    ; create header of new (empty) segment
    pla             ; restore LSB of the old next segment
    sta (ptr)       ; we know bit0==1
    pla
    ldy #1
    sta (ptr),y

    plp             ; restore alignment
    jsr @rollback_len_update

    lda #0  ; OK!
    rts

@error:
    ; restore stack
    ply ; (not needed) restore ptr to output addr
    plp ; restore whether len align==1 (C==1) or align==2
    jsr @rollback_len_update

    jsr io_push_put_byte
    .addr lcd_put_byte
    jsr io_put_const_string
    .asciiz "NOMEM"
    jsr io_pop_put_byte
    lda #1
    rts

; pre-condition: C==1 ? align==1 : align==2
; x = pointer to allocation size
@rollback_len_update:
    ; undo change in allocation size done at the beginning
    lda 0,x
    bcs @not_aligned
    ina
@not_aligned:
    sec
    sbc #3  ; if not aligned, will do LSB-3, or else, LSB+1-3 == LSB-2
    sta 0,x
    bcs @skip_msb3
    lda #0
    sbc 1,x ; decrement MSB (as C==0)
    sta 1,x
@skip_msb3:
    rts

; ================================================================
; x: zp pointer to word with address to be freed
; ret A: status 0->ok, 1->notfound
; obs: input pointer content gets garbled
sys_free:
    ; make input point to header of segment (ptr-2)
    lda 0,x
    sec
    sbc #2
    bcs @skip_msb
    lda 1,x
    dea
    sta 1,x
@skip_msb:

    ; mark it as free
    lda (0,x)
    ora #1
    sta (0,x)
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

