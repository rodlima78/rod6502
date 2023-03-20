ASFLAGS=-Fbin -dotdir -ce02
AS=vasm6502_oldstyle

src = running_leds.s testmem.s writemem.s dummy.s

objects = $(patsubst %.s,%.o,$(src))

all: $(objects)

$(objects): %.o : %.s
	$(AS) $< -o $@ $(ASFLAGS) -L $(patsubst %.o,%.l,$@)

clean:
	rm -f *.o *.l
