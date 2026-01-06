add_custom_command(OUTPUT araras.s
    COMMAND python3 ${CMAKE_CURRENT_SOURCE_DIR}/convimg.py ${CMAKE_CURRENT_SOURCE_DIR}/araras.png ${CMAKE_CURRENT_BINARY_DIR}/araras.s
)

add_executable(araras main.s ${CMAKE_CURRENT_BINARY_DIR}/araras.s)
target_link_libraries(araras bios)
