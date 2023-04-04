.import VIA_IO_B  ; input/output register 'B'
.import VIA_IO_A  ; input/output register 'A'
.import VIA_DIR_B ; data direction register 'B'
.import VIA_DIR_A ; data direction register 'A'
.import VIA_T1CL  ; (r) T1 low-order latch / (w) T1 low-order counter
.import VIA_T1CH  ; (r) T1 high-order latch / (w) T1 high-order counter 
.import VIA_T1LL
.import VIA_T1LH
.import VIA_T2CL  ; (r) T2 low-order counter
.import VIA_T2LL  ; (w) T2 low-order latch
.import VIA_T2CH
.import VIA_SR    ; Shift Register
.import VIA_ACR   ; Auxiliary Control Register
.import VIA_PCR   ; Peripheral Control Register
.import VIA_IFR   ; Interrupt Flags Register
.import VIA_IER   ; Interrupt Enable Register

.importzp VIA_LED_RED
.importzp VIA_LED_GREEN
