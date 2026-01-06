.include "sys.inc"
.include "vera.inc"
.include "io.inc"

.importzp img_width
.importzp img_height
.import img_size
.import img_data
.import pal_data
.export main

.zeropage
ptr: .res 2

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

    ; set bitmap mode, 8bpp
    lda #($04+3)
    sta VERA_L0_CONFIG

    ; 160x120
    lda #<img_width/5
    sta VERA_DC0_HSCALE
    lda #<img_height*4/15
    sta VERA_DC0_VSCALE

    ; tilew==320, start at $00000
    lda #$00
    sta VERA_L0_TILEBASE

    ; copy palette ---------------

    ; set write address to $1FA00
    stz VERA_ADDRx_L
    lda $FA
    sta VERA_ADDRx_M
    lda #1
    ora VERA_ADDRx_H
    sta VERA_ADDRx_H

    ldx #0
@looppal1:
    lda pal_data,x
    sta VERA_DATA0
    inx
    bne @looppal1
@looppal2:
    lda pal_data+256,x
    sta VERA_DATA0
    inx
    bne @looppal2

    ; copy image ---------------

    lda #<img_data
    sta ptr
    lda #>img_data
    sta ptr+1

    ; set write address to $00000
    stz VERA_ADDRx_L
    stz VERA_ADDRx_M
    lda #<~1
    and VERA_ADDRx_H
    sta VERA_ADDRx_H

    ldx #img_height
@loop_row:
    ldy #0
@loop_col:
    lda (ptr),y
    sta VERA_DATA0
    iny
    cpy #img_width
    bne @loop_col

    lda #img_width
    clc
    adc ptr
    sta ptr
    bcc @skip_msb
    inc ptr+1
@skip_msb:
    lda #<(320-img_width)
    clc
    adc VERA_ADDRx_L
    sta VERA_ADDRx_L
    lda #>(320-img_width)
    adc VERA_ADDRx_M
    sta VERA_ADDRx_M
    bcc @skip_addr_h
    inc VERA_ADDRx_H
@skip_addr_h:
    dex
    bne @loop_row

    jmp sys_exit
