# or debug
MODE       ?= release

ifeq "$(MODE)" "debug"
	CFLAGS += -g
	CFLAGS += -O0
else
	CFLAGS   += -O2
	CPPFLAGS += -DRELEASE
endif

CFLAGS     += -std=c11
CFLAGS     += -pedantic
CFLAGS     += -Wall
CFLAGS     += -Wextra
CFLAGS     += -Werror
CFLAGS     += -Wstrict-prototypes
CFLAGS     += -fPIC

LDLIBS     += -lpthread

CPPFLAGS   += -I includes
CPPFLAGS   += -I src

BUILD_DIR  := $(shell mkdir -p "build-$(MODE)" ; echo build-$(MODE) ; )

LIBRARY_A  := $(BUILD_DIR)/libretrojson.a
LIBRARY_SO := $(BUILD_DIR)/libretrojson.so
PRETTIFY   := $(BUILD_DIR)/prettify/a.out
TEST_STRESS     := $(BUILD_DIR)/test-stress/a.out
TEST_UNIT       := $(BUILD_DIR)/test-unit/a.out
TEST_COMPLIANCE := $(BUILD_DIR)/test-compliance/a.out
TEST_APPS  := $(TEST_STRESS) $(TEST_UNIT) $(TEST_COMPLIANCE)
APPS       := $(PRETTIFY) $(TEST_APPS)

.PHONY: all
all: $(LIBRARY_A) $(LIBRARY_SO) $(PRETTIFY)

# .c → .o compilation rule

CFILES := $(shell find * -name '*.c')
$(patsubst %.c, $(BUILD_DIR)/%.o, $(CFILES)): $(BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< $(CPPFLAGS) -o $@
	@$(CC) $(CFLAGS) -c $< $(CPPFLAGS) -MT $@ -MM -MF $(BUILD_DIR)/$*.dep

# application compilation rule
# applications are all directories with main.c

.SECONDEXPANSION:
$(APPS): $(BUILD_DIR)/%/a.out: \
$$(shell find % -name '*.c' | sed -E 's:(.*)\.c:$(BUILD_DIR)/\1.o:g') $(LIBRARY_A) 
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $^ -o $@ $(LDLIBS)

# libretrojson.a

CFILES     := $(shell find src -name '*.c')
ifeq "$(MODE)" "release"
	CFILES := $(filter-out dbg_%, $(CFILES))
endif
$(LIBRARY_A): $(patsubst %.c, $(BUILD_DIR)/%.o, $(CFILES))
	@mkdir -p $(dir $@)
	$(AR) -rcs $@ $^

$(LIBRARY_SO): $(patsubst %.c, $(BUILD_DIR)/%.o, $(CFILES))
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $^ -shared -o $@ $(LDLIBS)

# other targets

.PHONY: tests
tests: $(TEST_APPS)

.PHONY: check
check: tests 
	$(TEST_STRESS)
	$(TEST_UNIT)
	$(TEST_COMPLIANCE) ./test-compliance/JSONTestSuite/*

.PHONY: clean
clean:
	rm -rf build-*

-include $(shell find $(BUILD_DIR) -name '*.dep')

