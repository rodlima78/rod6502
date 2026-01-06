.include "sys.inc"
.include "vera.inc"

.export main

S = $0100

.code
main:
    ; reset VERA, set dcsel=0, addrsel=0
    lda #$80
    sta VERA_CTRL

    lda #$2a
@vera_init_wait:
    sta VERA_DATA0
    ldx VERA_DATA0
    cpx #$2a
    bne @vera_init_wait

    ; turn on video-RGB output, enable layer0
    lda #$11
    sta VERA_DC0_VIDEO

    ; set auto-increment to 1
    lda #$10
    sta VERA_ADDRx_H

    ; set bitmap mode
    lda #$04
    sta VERA_L0_CONFIG

    ; tilew==640
    lda #$01
    sta VERA_L0_TILEBASE

    ; set number of columns
    lda #$02    ; dcsel=1
    sta VERA_CTRL
    lda #(640>>2)
    sta VERA_DC1_HSTOP
    lda #(480>>1)
    sta VERA_DC1_VSTOP

    lda #>480
    pha
    lda #<480
    pha
    tsx
    inx

    lda #$ff
@clear_row:
    ldy #(640/8)
@clear_col:
    sta VERA_DATA0
    dey
    bne @clear_col

    ldy S,x
    bne @dec_lsb
    ldy S+1,x
    beq @break
    dec S+1,x
@dec_lsb:
    dec S,x
    bra @clear_row
@break:

    ; restore stack
    pla
    pla

    jmp sys_exit
