SNL ?= snl
BUILD_DIR ?= build/bootstrap
# `snl build` gera SnBC e empacota a VM C do snl; não é código de máquina.
COMPILER_BUNDLE := $(BUILD_DIR)/snova-bootstrap
VM_STAGE_IMAGE := $(BUILD_DIR)/vm-stage.snbc
VM_DIFF_FIXTURES := numericVm numericFlow hello vmCalls vmComposite
NATIVE_FIXTURES := numericVm numericFlow nativeCalls
SDK_PATH = $(shell xcrun --show-sdk-path)
SDK_VERSION = $(shell xcrun --show-sdk-version)
STAGE1_IMAGE := $(BUILD_DIR)/stage1.snbc
STAGE2_IMAGE := $(BUILD_DIR)/stage2.snbc
SMOKE_SOURCE := bootstrap/fixtures/hello.snl

.PHONY: bootstrap-check bootstrap-build bootstrap-self-host bootstrap-fixed-point bootstrap-smoke bootstrap-diagnostics bootstrap-image-check bootstrap-vm bootstrap-vm-self bootstrap-native

bootstrap-check:
	$(SNL) check --project bootstrap/src

bootstrap-build: bootstrap-check
	mkdir -p $(BUILD_DIR)
	$(SNL) build --project bootstrap/src -o $(COMPILER_BUNDLE)

bootstrap-self-host: bootstrap-build
	SNL_OUTPUT=$(STAGE1_IMAGE) $(COMPILER_BUNDLE)

bootstrap-fixed-point: bootstrap-self-host
	SNL_OUTPUT=$(STAGE2_IMAGE) $(SNL) run-snbc $(STAGE1_IMAGE)
	cmp $(STAGE1_IMAGE) $(STAGE2_IMAGE)

bootstrap-smoke: bootstrap-build
	$(COMPILER_BUNDLE) $(SMOKE_SOURCE) $(BUILD_DIR)/hello.snbc
	test "$$( $(SNL) run-snbc $(BUILD_DIR)/hello.snbc)" = "snova bootstrap ok"

bootstrap-diagnostics: bootstrap-build
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidLex.snl $(BUILD_DIR)/invalidLex.snbc > $(BUILD_DIR)/lexical-error.txt; then echo "expected lexical failure"; exit 1; fi
	grep -Fqx "lexical error at line 4" $(BUILD_DIR)/lexical-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidParse.snl $(BUILD_DIR)/invalidParse.snbc > $(BUILD_DIR)/parse-error.txt; then echo "expected parse failure"; exit 1; fi
	grep -Fqx "parse error at line 5" $(BUILD_DIR)/parse-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidRuntimeArity.snl $(BUILD_DIR)/invalidRuntimeArity.snbc > $(BUILD_DIR)/runtime-arity-error.txt; then echo "expected runtime arity failure"; exit 1; fi
	grep -Fqx "unsupported construct or invalid lowering" $(BUILD_DIR)/runtime-arity-error.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/warnMismatch.snl $(BUILD_DIR)/warnMismatch.snbc > $(BUILD_DIR)/warn-mismatch.txt
	printf 'warning[SNW0001]: comparison between different types at line 10\nwarning[SNW0001]: comparison between different types at line 13\n' | cmp - $(BUILD_DIR)/warn-mismatch.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/warnCompare.snl $(BUILD_DIR)/warnCompare.snbc > $(BUILD_DIR)/warn-compare.txt
	test ! -s $(BUILD_DIR)/warn-compare.txt
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/warnCompare.snbc run; test "$$?" -eq 7

bootstrap-image-check: bootstrap-self-host
	test "$$( $(COMPILER_BUNDLE) $(STAGE1_IMAGE))" = "valid SnBC image"
	head -c 8 $(STAGE1_IMAGE) > $(BUILD_DIR)/truncated.snbc
	@if $(COMPILER_BUNDLE) $(BUILD_DIR)/truncated.snbc > $(BUILD_DIR)/image-error.txt; then echo "expected image failure"; exit 1; fi
	grep -Fqx "invalid SnBC image" $(BUILD_DIR)/image-error.txt

# Diferencial: stdout e código de saída da VM Snova contra `snl run-snbc`.
# vmEquality e vmHostText têm saída esperada fixa porque o run-snbc v0.3.0
# compara strings por identidade e não repassa argumentos (ver evidence.md).
bootstrap-vm: bootstrap-build
	@for fixture in $(VM_DIFF_FIXTURES); do \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.snbc || exit 1; \
		$(SNL) run-snbc $(BUILD_DIR)/$$fixture.snbc > $(BUILD_DIR)/$$fixture.ref.txt; referenceExit=$$?; \
		$(COMPILER_BUNDLE) $(BUILD_DIR)/$$fixture.snbc run > $(BUILD_DIR)/$$fixture.vm.txt; vmExit=$$?; \
		test "$$referenceExit" -eq "$$vmExit" || { echo "$$fixture: exit $$vmExit != $$referenceExit"; exit 1; }; \
		cmp $(BUILD_DIR)/$$fixture.ref.txt $(BUILD_DIR)/$$fixture.vm.txt || exit 1; \
		echo "vm differential ok: $$fixture (exit $$vmExit)"; \
	done
	$(COMPILER_BUNDLE) bootstrap/fixtures/vmEquality.snl $(BUILD_DIR)/vmEquality.snbc
	test "$$( $(COMPILER_BUNDLE) $(BUILD_DIR)/vmEquality.snbc run | tr '\n' ' ')" = "true true true true true "
	$(COMPILER_BUNDLE) bootstrap/fixtures/vmHostText.snl $(BUILD_DIR)/vmHostText.snbc
	test "$$( SNOVA_FIXTURE_TEXT=probe $(COMPILER_BUNDLE) $(BUILD_DIR)/vmHostText.snbc run extra | tr '\n' ' ')" = "true true true "
	test "$$(cat $(BUILD_DIR)/vmHostText.txt)" = "probe"
	$(COMPILER_BUNDLE) bootstrap/fixtures/vmStackOverflow.snl $(BUILD_DIR)/vmStackOverflow.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmStackOverflow.snbc run > $(BUILD_DIR)/vmStackOverflow.vm.txt; test "$$?" -eq 70
	grep -Fqx "runtime error: Stack overflow" $(BUILD_DIR)/vmStackOverflow.vm.txt

# A VM Snova executa a imagem do compilador, que compila as próprias fontes;
# a imagem resultante deve ser igual à stage1. Leva alguns minutos porque a
# VM Snova roda sobre a VM C embutida pelo `snl build`.
bootstrap-vm-self: bootstrap-self-host
	SNL_OUTPUT=$(VM_STAGE_IMAGE) $(COMPILER_BUNDLE) $(STAGE1_IMAGE) run
	cmp $(STAGE1_IMAGE) $(VM_STAGE_IMAGE)

# Backend nativo N1 (ADR-0005): o compilador Snova emite assembly aarch64;
# `as`/`ld` do sistema montam e ligam. O código de saída do executável deve
# igualar o do executor Snova e o do `snl run-snbc`.
bootstrap-native: bootstrap-build
	@for fixture in $(NATIVE_FIXTURES); do \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native || exit 1; \
		as -arch arm64 $(BUILD_DIR)/$$fixture.s -o $(BUILD_DIR)/$$fixture.o || exit 1; \
		ld -arch arm64 -platform_version macos $(SDK_VERSION) $(SDK_VERSION) -syslibroot $(SDK_PATH) -lSystem -e _main $(BUILD_DIR)/$$fixture.o -o $(BUILD_DIR)/$$fixture.native || exit 1; \
		$(BUILD_DIR)/$$fixture.native; nativeExit=$$?; \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.snbc || exit 1; \
		$(COMPILER_BUNDLE) $(BUILD_DIR)/$$fixture.snbc run > /dev/null; vmExit=$$?; \
		$(SNL) run-snbc $(BUILD_DIR)/$$fixture.snbc > /dev/null; referenceExit=$$?; \
		test "$$nativeExit" -eq "$$vmExit" -a "$$nativeExit" -eq "$$referenceExit" || { echo "$$fixture: native $$nativeExit vm $$vmExit ref $$referenceExit"; exit 1; }; \
		echo "native differential ok: $$fixture (exit $$nativeExit)"; \
	done
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/hello.snl $(BUILD_DIR)/hello.s native > $(BUILD_DIR)/native-error.txt; then echo "expected native failure"; exit 1; fi
	grep -Fqx "unsupported opcode for native backend: 3" $(BUILD_DIR)/native-error.txt
