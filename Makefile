ASM      := sjasmplus
EMU      := zesarux
PYTHON   := python3

SRC      := src/main.asm
BUILD    := build
SNA      := $(BUILD)/game.sna
TAP      := $(BUILD)/game.tap
BIN      := $(BUILD)/game.bin
SLD      := $(BUILD)/game.sld
LST      := $(BUILD)/game.lst
SYM      := $(BUILD)/game.sym
ZRCP_PORT ?= 10000

.PHONY: all build run run-tap debug inspect web serve clean

all: build

build:
	mkdir -p $(BUILD)
	$(ASM) --fullpath --sld=$(SLD) --lst=$(LST) --sym=$(SYM) $(SRC)
	mkdir -p docs
	cp $(TAP) docs/gta82.tap

web: build

serve: build
	$(PYTHON) -m http.server 8000 --directory docs

run: build
	$(EMU) --nowelcomemessage --quickexit $(CURDIR)/$(SNA)

run-tap: build
	$(EMU) --nowelcomemessage --quickexit $(CURDIR)/$(TAP)

debug: build
	$(EMU) --enable-remoteprotocol --remoteprotocol-port $(ZRCP_PORT) --nowelcomemessage --quickexit $(CURDIR)/$(SNA)

inspect:
	$(PYTHON) tools/zrcp.py --port $(ZRCP_PORT)

clean:
	rm -rf $(BUILD)
