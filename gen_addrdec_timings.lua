#!/usr/bin/lua

clock_freq = 5.125e6 -- Hertz
--clock_freq = 4e6 -- Hertz

-- timings in nanoseconds

-- WS65C02S
cpu_tads = 30 -- Max Address Setup Time
cpu_tah = 10  -- Min Address Hold Time
cpu_tdsr = 10 -- Min Read Data Setup Time
cpu_tdhr = 10 -- Min Read Data Hold Time

-- AS6C62256
ram_tace = 55 -- Max Chip Enable Access Time
ram_toh = 10  -- Min Output Hold from Address Change
ram_tchz = 20 -- Max Chip Disable to Output in High-Z
ram_tclz = 10 -- Min Chip Enable to Output in Low-Z

-- AT28C256
rom_tce = 150 -- Max Chip Enable to Output Delay
rom_toh = 0   -- Min Output Hold from CE, OE or address (whichever occurred first)
rom_tdf = 50  -- Max CE or OE to Output FLoat

-- LS / HCT
ram0_tpd_lh = 15
ram0_tpd_hl = 35
ram1_tpd_lh = 20
ram1_tpd_hl = 55

rom_tpd_lh = 50
rom_tpd_hl = 50

-- AS / AST / AHCT
ram0_tpd_lh = 8 -- 7.9
ram0_tpd_hl = 13 -- 12.9
ram1_tpd_lh = 8 -- 7.9
ram1_tpd_hl = 13 -- 13.4

rom_tpd_lh = 18 -- 18.4
rom_tpd_hl = 18 -- 18.4

----------------------------

function printf(fmt,...)
    print(string.format(fmt, ...))
end

function round(x)
    return math.floor(x+0.5)
end

clock_period = round(1e9/clock_freq)

clock_start = 0
clock_end = clock_start+clock_period

printf([[
@startuml
Title ROD6502 Timing Diagram
scale 10 as 40 pixels

clock "clock" as clock with period %d offset %d
concise "Address" as addr
concise "CPU read" as cpudata
concise "RAM0 read" as ram0data
binary "RAM0 CS" as ram0cs
concise "RAM1 read" as ram1data
binary "RAM1 CS" as ram1cs
concise "ROM read" as romdata
binary "ROM CS" as romcs
]], clock_period, round(clock_period/2))

-- start condition
printf([[
@%d
addr is {-}
cpudata is {-}
]],clock_start)

-- cpu
address_ready = clock_start + cpu_tads
printf("addr@%d <-> @+%d: {setup %d ns}\n",clock_start,cpu_tads,cpu_tads)
printf([[@%d
addr is "address"
]], address_ready)

cpu_readdata_start = round(clock_period-cpu_tdsr)
printf([[
@%d
cpudata is "cpu read"
]],cpu_readdata_start)

addr_end = clock_period + cpu_tah
printf([[
@%d
addr is {-}
]], addr_end)

cpu_readdata_end = round(clock_period+cpu_tdhr)
printf([[
@%d
cpudata is {-}
]],cpu_readdata_end)

-- ram0 read
printf([[
@%d
ram0data is {-}
ram0cs is high
]],clock_start)

ram0_cs_active = address_ready + ram0_tpd_hl
printf("ram0cs@%d <-> @+%d: {tpd HL %d ns}",address_ready, ram0_tpd_hl,ram0_tpd_hl)
printf([[
@%d
ram0cs is low
]], ram0_cs_active)

ram0_read_data_loZ = ram0_cs_active + ram_tclz
printf([[
@%d
ram0data is "low Z"
]],ram0_read_data_loZ)

ram0_read_data_ready = ram0_cs_active + ram_tace
printf("ram0data@%d <-> @+%d: {read %d ns}",ram0_cs_active,ram_tace,ram_tace)
printf([[
@%d
ram0data is "ram0 read"
]],ram0_read_data_ready)

ram0_read_data_end = addr_end + ram_toh
printf([[
@%d
ram0data is "low Z"
]],ram0_read_data_end)

ram0_cs_inactive = addr_end + ram0_tpd_lh
printf("ram0cs@%d <-> @+%d: {tpd LH %d ns}",addr_end, ram0_tpd_lh,ram0_tpd_lh)
printf([[
@%d
ram0cs is high
]],ram0_cs_inactive)

ram0_read_data_hiZ = ram0_cs_inactive + ram_tchz
printf([[
@%d
ram0data is {-}
]],ram0_read_data_hiZ)

-- ram1 read
printf([[
@%d
ram1data is {-}
ram1cs is high
]],clock_start)

ram1_cs_active = address_ready + ram1_tpd_hl
printf("ram1cs@%d <-> @+%d: {tpd HL %d ns}",address_ready, ram1_tpd_hl,ram1_tpd_hl)
printf([[
@%d
ram1cs is low
]], ram1_cs_active)

ram1_read_data_loZ = ram1_cs_active + ram_tclz
printf([[
@%d
ram1data is "low Z"
]],ram1_read_data_loZ)

ram1_read_data_ready = ram1_cs_active + ram_tace
printf("ram1data@%d <-> @+%d: {read %d ns}",ram1_cs_active,ram_tace,ram_tace)
printf([[
@%d
ram1data is "ram1 read"
]],ram1_read_data_ready)

ram1_read_data_end = addr_end + ram_toh
printf([[
@%d
ram1data is "low Z"
]],ram1_read_data_end)

ram1_cs_inactive = addr_end + ram1_tpd_lh
printf("ram1cs@%d <-> @+%d: {tpd LH %d ns}",addr_end, ram1_tpd_lh,ram1_tpd_lh)
printf([[
@%d
ram1cs is high
]],ram1_cs_inactive)

ram1_read_data_hiZ = ram1_cs_inactive + ram_tchz
printf([[
@%d
ram1data is {-}
]],ram1_read_data_hiZ)

-- rom read
printf([[
@%d
romdata is {-}
romcs is high
]],clock_start)

rom_cs_active = address_ready + rom_tpd_hl
printf("romcs@%d <-> @+%d: {tpd HL %d ns}",address_ready, rom_tpd_hl,rom_tpd_hl)
printf([[
@%d
romcs is low
]], rom_cs_active)

rom_read_data_lowZ = rom_cs_active
printf([[
@%d
romdata is "low Z (?)"
]],rom_read_data_lowZ)

rom_read_data_ready = rom_cs_active + rom_tce
printf("romdata@%d <-> @+%d: {read %d ns}",rom_cs_active,rom_tce,rom_tce)
printf([[
@%d
romdata is "rom read"
]],rom_read_data_ready)

rom_cs_inactive = addr_end + rom_tpd_lh
printf("romcs@%d <-> @+%d: {tpd LH %d ns}",addr_end, rom_tpd_lh,rom_tpd_lh)
printf([[
@%d
romcs is high
]],rom_cs_inactive)

rom_read_data_end = math.min(addr_end,rom_cs_inactive) + rom_toh
printf([[
@%d
romdata is "low Z"
]],rom_read_data_end)

rom_read_data_hiZ = rom_cs_inactive + rom_tdf
printf([[
@%d
romdata is {-}
]],rom_read_data_hiZ)

print("@enduml")
