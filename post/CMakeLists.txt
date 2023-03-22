project(post ASM)

add_executable(post post.s testmem.s testvia.s)
target_link_libraries(post rt6502)
