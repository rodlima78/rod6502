cmake_minimum_required(VERSION 3.16)
set(CMAKE_TOOLCHAIN_FILE cmake/cc65-toolchain.cmake)

project(rod6502 ASM)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/bin)

add_subdirectory(bios)
