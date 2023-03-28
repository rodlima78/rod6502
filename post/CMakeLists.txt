project(post ASM)

add_executable(post post.s testmem.s testirq.s testacia.s)
target_link_libraries(post rt6502)
