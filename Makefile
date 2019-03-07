PURPLE_PLUGIN_DIR=~/.purple/plugins
#PIDGIN_DIR=./pidgin-2.11.0
#PURPLE_PLUGIN_SRC_DIR=$(PIDGIN_DIR)/libpurple/plugins

CC ?= gcc
PKG_CONFIG ?= pkg-config

LDIR=./lib
BDIR=./build
SDIR=./src
HDIR=./headers
TDIR=./test
PURPLE_DIR=$(shell $(PKG_CONFIG) --variable=plugindir purple)

GLIB_CFLAGS ?= $(shell $(PKG_CONFIG) --cflags glib-2.0)
GLIB_LDFLAGS ?= $(shell $(PKG_CONFIG) --libs glib-2.0)

LIBPURPLE_CFLAGS ?= $(shell $(PKG_CONFIG) --cflags purple)
LIBPURPLE_LDFLAGS ?= $(shell $(PKG_CONFIG) --cflags purple) -L$(PURPLE_DIR)

XML2_CONFIG ?= xml2-config
XML2_CFLAGS ?= $(shell $(XML2_CONFIG) --cflags)
XML2_LDFLAGS ?= $(shell $(XML2_CONFIG) --libs)


HEADERS=-I$(HDIR)/jabber

PKGCFG_C=$(GLIB_CFLAGS) \
	 $(LIBPURPLE_CFLAGS) \
	 $(XML2_CFLAGS)

PKGCFG_L=$(GLIB_LDFLAGS) \
	 $(LIBPURPLE_LDFLAGS) \
	 $(XML2_LDFLAGS)

CFLAGS=-std=c11 -Wall -g -Wstrict-overflow -D_XOPEN_SOURCE=700 -D_BSD_SOURCE -D_DEFAULT_SOURCE $(PKGCFG_C) $(HEADERS)
CFLAGS_C= $(CFLAGS) -fPIC -shared
CFLAGS_T= $(CFLAGS) -O0
PLUGIN_CPPFLAGS=-DPURPLE_PLUGINS

ifneq ("$(wildcard /etc/redhat-release)","")
	LJABBER?=-lxmpp
else
	LJABBER?=-ljabber
endif

LFLAGS= -ldl -lm $(PKGCFG_L) $(LJABBER)
LFLAGS_T= $(LFLAGS) -lpurple -lcmocka -Wl,-rpath,$(PURPLE_DIR) \
	-Wl,--wrap=purple_account_get_username \
	-Wl,--wrap=purple_account_get_connection \
	-Wl,--wrap=purple_accounts_get_handle \
	-Wl,--wrap=purple_debug_error \
	-Wl,--wrap=purple_debug_warning \
	-Wl,--wrap=purple_connection_get_account \
	-Wl,--wrap=purple_connection_get_protocol_data \
	-Wl,--wrap=purple_find_conversation_with_account \
	-Wl,--wrap=purple_conversation_new \
	-Wl,--wrap=purple_conversation_write \
	-Wl,--wrap=purple_plugins_find_with_id \
	-Wl,--wrap=purple_signal_connect \
	-Wl,--wrap=purple_signal_connect_priority \
	-Wl,--wrap=jabber_add_feature \
	-Wl,--wrap=jabber_iq_send

all: $(BDIR)/carbons.so

$(BDIR):
	mkdir -p build

$(BDIR)/%.o: $(SDIR)/%.c $(BDIR)
	$(CC) $(CFLAGS_C) $(PLUGIN_CPPFLAGS) -c $(SDIR)/$*.c -o $@

$(BDIR)/carbons.so: $(BDIR)/carbons.o
	$(CC) $(CFLAGS_C) $(PLUGIN_CPPFLAGS) $(BDIR)/carbons.o -o $@ $(LFLAGS)
$(BDIR)/carbons.a: $(BDIR)/carbons.o
	$(AR) rcs $@ $^

install: $(BDIR)/carbons.so
	mkdir -p $(PURPLE_PLUGIN_DIR)
	cp $(BDIR)/carbons.so $(PURPLE_PLUGIN_DIR)/carbons.so

.PHONY: test
test: $(TDIR)/test_carbons.c $(BDIR)
	$(CC) $(CFLAGS_T) -c $< -o $(BDIR)/$@.o
	$(CC) $(CFLAGS_T) --coverage  -c $(SDIR)/carbons.c -o $(BDIR)/carbons_coverage.o
	$(CC) $(CFLAGS_T) --coverage $(PURPLE_DIR)/libjabber.so.0 $(BDIR)/$@.o $(BDIR)/carbons_coverage.o -o $(BDIR)/$@ $(LFLAGS_T)
	-$(BDIR)/$@ 2>&1 | grep -Ev ".*CRITICAL.*" | tr -s '\n' # filter annoying and irrelevant glib output

.PHONY: coverage
coverage: test
	gcovr -r . --html --html-details -o build/coverage.html
	gcovr -r . -s

.PHONY: clean
clean:
	rm -rf $(BDIR)
