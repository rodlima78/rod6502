; memories
.import __RAM_START__
.import __RAM_SIZE__
.import __RAM_LAST__

.import __ROM_START__
.import __ROM_SIZE__
.import __ROM_LAST__

.import __IO_START__
.import __IO_SIZE__
.import __IO_LAST__

; segments
.import __CODE_SIZE__
.import __CODE_LOAD__
.import __CODE_RUN__

.import __RODATA_RUN__
.import __RODATA_SIZE__

.import __VECTORS_RUN__
.import __VECTORS_SIZE__

.import __ZEROPAGE_RUN__
.import __ZEROPAGE_SIZE__

.import __STACK_RUN__
.import __STACK_SIZE__

.import __DATA_RUN__
.import __DATA_SIZE__

.import __HEAP_RUN__
.import __HEAP_SIZE__

; functions
.global sys_malloc
.global sys_free
