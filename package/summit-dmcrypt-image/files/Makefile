# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
CC      ?= gcc
CFLAGS  ?= -O2
LDFLAGS ?=
LIBS    := -lcrypto

PREFIX  ?= /usr
BINDIR  := $(DESTDIR)$(PREFIX)/bin

TARGET  := dmcrypt_image
SRC     := dmcrypt_image.c

.PHONY: all install clean test

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LIBS)

install: $(TARGET)
	install -D -m 0755 $(TARGET) $(BINDIR)/$(TARGET)

clean:
	$(RM) $(TARGET)

test: $(TARGET)
	sudo ./test_dmcrypt_image.sh
