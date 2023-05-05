project(bios ASM)

# BIOS interface to apps -----------
add_library(bios INTERFACE)
target_include_directories(bios INTERFACE include)
target_link_options(bios INTERFACE -C ${CMAKE_CURRENT_SOURCE_DIR}/firmware_apps.cfg)
set_target_properties(bios PROPERTIES
    INTERFACE_LINK_DEPENDS
        ${CMAKE_CURRENT_SOURCE_DIR}/firmware_apps.cfg
)

# BIOS ROM -------------------------
add_executable(bios_rom
    main.s
    lcd.s
    sys.s
    irq.s
    acia.s
    mem.s
    xmodem.s
    cmd.s
    cmd_load.s
    cmd_run.s
    cmd_mdump.s
    io.s
    strlist.s
    post/post.s
    post/testmem.s
    post/testirq.s
)
set_target_properties(bios_rom PROPERTIES OUTPUT_NAME bios)
target_include_directories(bios_rom PRIVATE include)
target_link_options(bios_rom PRIVATE
    -C ${CMAKE_CURRENT_SOURCE_DIR}/firmware_bios.cfg
    -m bios.map
    --dbgfile bios.dbg
)
set_target_properties(bios_rom PROPERTIES
    LINK_DEPENDS
        ${CMAKE_CURRENT_SOURCE_DIR}/firmware_bios.cfg
)
