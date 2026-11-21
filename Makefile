SNL ?= snl
BUILD_DIR ?= build/bootstrap
COMPILER_SOURCE := $(BUILD_DIR)/compiler.snl
COMPILER_NATIVE := $(BUILD_DIR)/snova-bootstrap
STAGE1_IMAGE := $(BUILD_DIR)/stage1.snbc
STAGE2_IMAGE := $(BUILD_DIR)/stage2.snbc
SMOKE_SOURCE := bootstrap/fixtures/hello.snl

.PHONY: bootstrap-source bootstrap-check bootstrap-build bootstrap-self-host bootstrap-fixed-point bootstrap-smoke bootstrap-diagnostics

bootstrap-source:
	mkdir -p $(BUILD_DIR)
	$(SNL) check bootstrap/tools/join.snl
	$(SNL) build bootstrap/tools/join.snl -o $(BUILD_DIR)/snovaJoin
	./$(BUILD_DIR)/snovaJoin

bootstrap-check: bootstrap-source
	$(SNL) check --project bootstrap/src
	$(SNL) check $(COMPILER_SOURCE)

bootstrap-build: bootstrap-check
	$(SNL) build $(COMPILER_SOURCE) -o $(COMPILER_NATIVE)

bootstrap-self-host: bootstrap-build
	cp $(COMPILER_SOURCE) $(BUILD_DIR)/in.snl
	cd $(BUILD_DIR) && ./snova-bootstrap
	cp $(BUILD_DIR)/out.snbc $(STAGE1_IMAGE)

bootstrap-fixed-point: bootstrap-self-host
	cd $(BUILD_DIR) && $(SNL) run-snbc stage1.snbc
	cp $(BUILD_DIR)/out.snbc $(STAGE2_IMAGE)
	cmp $(STAGE1_IMAGE) $(STAGE2_IMAGE)

bootstrap-smoke: bootstrap-build
	cp $(SMOKE_SOURCE) $(BUILD_DIR)/in.snl
	cd $(BUILD_DIR) && ./snova-bootstrap
	test "$$(cd $(BUILD_DIR) && $(SNL) run-snbc out.snbc)" = "snova bootstrap ok"

bootstrap-diagnostics: bootstrap-build
	cp bootstrap/fixtures/invalidLex.snl $(BUILD_DIR)/in.snl
	@if (cd $(BUILD_DIR) && ./snova-bootstrap > lexical-error.txt); then echo "expected lexical failure"; exit 1; fi
	grep -Fqx "lexical error in in.snl at line 4" $(BUILD_DIR)/lexical-error.txt
	cp bootstrap/fixtures/invalidParse.snl $(BUILD_DIR)/in.snl
	@if (cd $(BUILD_DIR) && ./snova-bootstrap > parse-error.txt); then echo "expected parse failure"; exit 1; fi
	grep -Fqx "parse error in in.snl at line 5" $(BUILD_DIR)/parse-error.txt
