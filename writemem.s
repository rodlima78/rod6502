START_ROM = $C800
RESET_VEC = $FFFC

 .org $8000
 .org START_ROM

reset:
 ldx #0 ; value to be stored
 ldy #0 ; index within page
loop_w_zp:
 stx 0,y
 inx
 iny
 jmp loop_w_zp

 .org RESET_VEC
 .word reset
 .word $0000

