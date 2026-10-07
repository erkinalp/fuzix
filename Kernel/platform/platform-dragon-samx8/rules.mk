CROSS_CCOPTS += -I$(FUZIX_ROOT)/Kernel/platform/platform-dragon-nx32
CROSS_CCOPTS += -I$(FUZIX_ROOT)/Kernel/platform/platform-coco3
CROSS_CCOPTS += -p $(FUZIX_ROOT)/Kernel/build/rules.6809

# Partially reproduces the target selection logic in platform Makefile

ifndef SUBTARGET
SUBTARGET = sdc
endif

ifeq ($(SUBTARGET),sdc)
ifndef WANT_COCOSDC
WANT_COCOSDC = yes
endif
endif

ifeq ($(SUBTARGET),emu)
ifndef WANT_DRIVEWIRE
WANT_DRIVEWIRE = yes
endif
endif

ifeq ($(WANT_COCOSDC),yes)
CROSS_CCOPTS += -DCMDLINE=\"hda1\"
else ifeq ($(WANT_DRIVEWIRE),yes)
CROSS_CCOPTS += -DCMDLINE=\"dw\"
endif
