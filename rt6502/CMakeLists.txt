cmake_minimum_required(VERSION 3.16)
set(CMAKE_TOOLCHAIN_FILE ../cmake/cc65-toolchain.cmake)

project(rt6502 ASM)

add_library(rt6502 lcd.s)
target_compile_definitions(rt6502 PRIVATE -DRT6502_EXPORTING=1)
target_include_directories(rt6502 PUBLIC include)

install(TARGETS rt6502)
install(DIRECTORY include
    DESTINATION ${CMAKE_INSTALL_PREFIX}
)
