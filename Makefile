SNL ?= snl
BUILD_DIR ?= build/bootstrap
COMPILER_NATIVE := $(BUILD_DIR)/snova-bootstrap
STAGE1_IMAGE := $(BUILD_DIR)/stage1.snbc
STAGE2_IMAGE := $(BUILD_DIR)/stage2.snbc
SMOKE_SOURCE := bootstrap/fixtures/hello.snl

.PHONY: bootstrap-check bootstrap-build bootstrap-self-host bootstrap-fixed-point bootstrap-smoke bootstrap-diagnostics bootstrap-image-check

bootstrap-check:
	$(SNL) check --project bootstrap/src

bootstrap-build: bootstrap-check
	mkdir -p $(BUILD_DIR)
	$(SNL) build --project bootstrap/src -o $(COMPILER_NATIVE)

bootstrap-self-host: bootstrap-build
	SNL_OUTPUT=$(STAGE1_IMAGE) $(COMPILER_NATIVE)

bootstrap-fixed-point: bootstrap-self-host
	SNL_OUTPUT=$(STAGE2_IMAGE) $(SNL) run-snbc $(STAGE1_IMAGE)
	cmp $(STAGE1_IMAGE) $(STAGE2_IMAGE)

bootstrap-smoke: bootstrap-build
	$(COMPILER_NATIVE) $(SMOKE_SOURCE) $(BUILD_DIR)/hello.snbc
	test "$$( $(SNL) run-snbc $(BUILD_DIR)/hello.snbc)" = "snova bootstrap ok"

bootstrap-diagnostics: bootstrap-build
	@if $(COMPILER_NATIVE) bootstrap/fixtures/invalidLex.snl $(BUILD_DIR)/invalidLex.snbc > $(BUILD_DIR)/lexical-error.txt; then echo "expected lexical failure"; exit 1; fi
	grep -Fqx "lexical error at line 4" $(BUILD_DIR)/lexical-error.txt
	@if $(COMPILER_NATIVE) bootstrap/fixtures/invalidParse.snl $(BUILD_DIR)/invalidParse.snbc > $(BUILD_DIR)/parse-error.txt; then echo "expected parse failure"; exit 1; fi
	grep -Fqx "parse error at line 5" $(BUILD_DIR)/parse-error.txt

bootstrap-image-check: bootstrap-self-host
	test "$$( $(COMPILER_NATIVE) $(STAGE1_IMAGE))" = "valid SnBC image"
	head -c 8 $(STAGE1_IMAGE) > $(BUILD_DIR)/truncated.snbc
	@if $(COMPILER_NATIVE) $(BUILD_DIR)/truncated.snbc > $(BUILD_DIR)/image-error.txt; then echo "expected image failure"; exit 1; fi
	grep -Fqx "invalid SnBC image" $(BUILD_DIR)/image-error.txt
