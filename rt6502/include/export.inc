.ifdef RT6502_EXPORTING
    .define RT6502_PUBLIC .export
    .define RT6502_PUBLIC_ZP .exportzp
.else
    .define RT6502_PUBLIC .import
    .define RT6502_PUBLIC_ZP .importzp
.endif
