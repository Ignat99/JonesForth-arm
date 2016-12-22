SHELL := /bin/bash
AS := gcc 
CC := gcc 
LD := ld
OBJCOPY := objcopy

PROGRAM := jonesforth

# Enable building for the BeagleBoneBlack
BBB ?= 0

C_SRCS := $(wildcard *.c)
S_SRCS := $(wildcard *.s)

OBJS := $(patsubst %.s,%.o,$(S_SRCS))
OBJS += $(patsubst %.c,%.o,$(C_SRCS))

INCLUDE := -Iinclude
LSCRIPT := linker.ld

BUILD_ID_NONE := -Wl,--build-id=none
#BUILD_ID_NONE :=
BASEFLAGS := -g -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard 
WARNFLAGS := -Wall -Werror -Wno-missing-prototypes -Wno-unused-macros -Wno-bad-function-cast -Wno-sign-conversion
# CFLAGS := -std=c99 -fno-builtin -ffreestanding -fomit-frame-pointer $(DEFINES) $(BASEFLAGS) $(WARNFLAGS) $(INCLUDE)
LDFLAGS := -nostdlib -nostdinc -nodefaultlibs -nostartfiles -T $(LSCRIPT)
ASFLAGS := $(BASEFLAGS) $(WARNFLAGS) -x assembler-with-cpp 
OCFLAGS := --target elf32-littlearm --set-section-flags .bss=contents,alloc,load -O binary
CFLAGS := -std=c99 -nostdlib -static -fno-builtin -ffreestanding -fomit-frame-pointer $(BUILD_ID_NONE) $(DEFINES) $(BASEFLAGS) $(WARNFLAGS) $(INCLUDE)

ifeq ($(BBB), 1)
	CFLAGS += -DBBB=1
	ASFLAGS += -DBBB=1
endif

$(PROGRAM): $(PROGRAM).S
	$(CC) $(CFLAGS) -o $@ $<

$(PROGRAM).bin: $(PROGRAM).elf
	$(OBJCOPY) $(OCFLAGS) $< $@

$(PROGRAM).elf: $(OBJS) linker.ld
	$(LD) $(LDFLAGS) $(OBJS) -o $@

%.o: %.S Makefile
	$(AS) $(ASFLAGS) -c $< -o $@

%.o: %.c Makefile
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	$(RM) -f perf_dupdrop *~ core .test_* $(OBJS) $(PROGRAM).elf $(PROGRAM).bin $(PROGRAM)

# Tests.

TESTS	:= $(patsubst %.f,%.test,$(wildcard test_*.f))

test check: $(TESTS)

test_%.test: test_%.f jonesforth
	@echo -n "$< ... "
	@rm -f .$@
	@cat <(echo ': TEST-MODE ;') jonesforth.f $< <(echo 'TEST') | ./jonesforth 2>&1 | sed 's/DSP=[0-9]*//g' > .$@
	@diff -u .$@ $<.out
	@rm -f .$@
	@echo "ok"

.SUFFIXES: .f .test
.PHONY: test check run run_perf_dupdrop clean

