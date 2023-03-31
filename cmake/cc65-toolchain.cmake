# CMake toolchain file for cc65

set(CMAKE_SYSTEM_NAME Generic)

set(CMAKE_C_COMPILER cc65)
set(CMAKE_ASM_COMPILER ca65)

find_program(CMAKE_AR ar65)
find_program(CMAKE_LINKER ld65)

# \note Need to delete the old file first because ar65 can only add files
#       into an archive (or remove named files, but we don't know the names).
set(CMAKE_ASM_CREATE_STATIC_LIBRARY
    "<CMAKE_COMMAND> -E remove <TARGET> "
    "<CMAKE_AR> a <TARGET> <LINK_FLAGS> <OBJECTS>"
)
set(CMAKE_ASM_COMPILE_OBJECT "<CMAKE_ASM_COMPILER> <FLAGS> <INCLUDES> <DEFINES> <SOURCE> -o <OBJECT>")
set(CMAKE_DEPFILE_FLAGS_ASM "--create-full-dep <DEP_FILE>")
set(CMAKE_ASM_DEPENDS_USE_COMPILER TRUE)
set(CMAKE_ASM_DEPFILE_FORMAT "gcc")
set(CMAKE_ASM_LINK_EXECUTABLE "<CMAKE_LINKER> -o <TARGET> <OBJECTS> <CMAKE_ASM_LINK_FLAGS> <LINK_FLAGS> <LINK_LIBRARIES>")
set(CMAKE_ASM_OUTPUT_EXTENSION ".o")
set(CMAKE_ASM_FLAGS_INIT "--cpu 65C02")

define_property(TARGET PROPERTY FIRMWARE INHERITED)
