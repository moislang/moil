SNL ?= snl
BUILD_DIR ?= build/bootstrap
# `snl build` gera SnBC e empacota a VM C do snl; não é código de máquina.
COMPILER_BUNDLE := $(BUILD_DIR)/snova-bootstrap
VM_STAGE_IMAGE := $(BUILD_DIR)/vm-stage.snbc
VM_DIFF_FIXTURES := numericVm numericFlow hello vmCalls vmComposite staticMethods
NATIVE_FIXTURES := numericVm numericFlow nativeCalls
NATIVE_RUNTIME_FIXTURES := hello vmCalls vmComposite vmEquality vmStackOverflow nativeHostIo nativeMemory staticMethods
# Programs that end normally must free every block before exit.
NATIVE_OWNERSHIP_FIXTURES := hello vmCalls vmComposite vmEquality nativeHostIo nativeMemory staticMethods
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
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidStaticCall.snl $(BUILD_DIR)/invalidStaticCall.snbc > $(BUILD_DIR)/static-call-error.txt; then echo "expected static call failure"; exit 1; fi
	grep -Fqx "unsupported construct or invalid lowering" $(BUILD_DIR)/static-call-error.txt
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

# Native backend (ADR-0005, ADR-0006): the Snova compiler emits aarch64
# assembly for the program plus the Snova runtime in bootstrap/runtime; the
# system `as`/`ld` only assemble and link. Numeric fixtures must match the
# exit status of the Snova executor and of `snl run-snbc`; runtime fixtures
# must match the Snova executor's stdout and exit status.
NATIVE_LINK = as -arch arm64 $(BUILD_DIR)/$$fixture.s -o $(BUILD_DIR)/$$fixture.o && \
	ld -arch arm64 -platform_version macos $(SDK_VERSION) $(SDK_VERSION) -syslibroot $(SDK_PATH) -lSystem -e _main $(BUILD_DIR)/$$fixture.o -o $(BUILD_DIR)/$$fixture.native

bootstrap-native: bootstrap-build
	@for fixture in $(NATIVE_FIXTURES); do \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native || exit 1; \
		$(NATIVE_LINK) || exit 1; \
		$(BUILD_DIR)/$$fixture.native; nativeExit=$$?; \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.snbc || exit 1; \
		$(COMPILER_BUNDLE) $(BUILD_DIR)/$$fixture.snbc run > /dev/null; vmExit=$$?; \
		$(SNL) run-snbc $(BUILD_DIR)/$$fixture.snbc > /dev/null; referenceExit=$$?; \
		test "$$nativeExit" -eq "$$vmExit" -a "$$nativeExit" -eq "$$referenceExit" || { echo "$$fixture: native $$nativeExit vm $$vmExit ref $$referenceExit"; exit 1; }; \
		echo "native differential ok: $$fixture (exit $$nativeExit)"; \
	done
	@for fixture in $(NATIVE_RUNTIME_FIXTURES); do \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native || exit 1; \
		$(NATIVE_LINK) || exit 1; \
		$(BUILD_DIR)/$$fixture.native alpha beta > $(BUILD_DIR)/$$fixture.native.txt; nativeExit=$$?; \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.snbc || exit 1; \
		$(COMPILER_BUNDLE) $(BUILD_DIR)/$$fixture.snbc run alpha beta > $(BUILD_DIR)/$$fixture.vm.txt; vmExit=$$?; \
		test "$$nativeExit" -eq "$$vmExit" || { echo "$$fixture: native exit $$nativeExit != vm $$vmExit"; exit 1; }; \
		cmp $(BUILD_DIR)/$$fixture.native.txt $(BUILD_DIR)/$$fixture.vm.txt || exit 1; \
		echo "native runtime differential ok: $$fixture (exit $$nativeExit)"; \
	done
	@fixture=vmHostText; printf stale > $(BUILD_DIR)/vmHostText.txt; \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native && $(NATIVE_LINK) || exit 1; \
		SNOVA_FIXTURE_TEXT=probe $(BUILD_DIR)/$$fixture.native extra > $(BUILD_DIR)/$$fixture.native.txt; test "$$?" -eq 1 || exit 1; \
		test "$$(tr '\n' ' ' < $(BUILD_DIR)/$$fixture.native.txt)" = "true true true " || exit 1; \
		test "$$(cat $(BUILD_DIR)/vmHostText.txt)" = "probe" || exit 1; \
		echo "native host text ok: $$fixture (exit 1)"
	@for fixture in $(NATIVE_OWNERSHIP_FIXTURES); do \
		SNOVA_MEMORY_REPORT=1 $(BUILD_DIR)/$$fixture.native alpha beta 2>&1 > /dev/null | grep -q "live blocks 0, live bytes 0" || { echo "$$fixture: memory still live at exit"; exit 1; }; \
	done; echo "native ownership ok: zero live blocks at exit"
	@fixture=nativeMemory; \
		SNOVA_MEMORY_REPORT=1 $(BUILD_DIR)/$$fixture.native a 2>&1 > /dev/null | grep -o "peak bytes [0-9]*" > $(BUILD_DIR)/$$fixture.peak1.txt; \
		SNOVA_MEMORY_REPORT=1 $(BUILD_DIR)/$$fixture.native a a a a a a a a 2>&1 > /dev/null | grep -o "peak bytes [0-9]*" > $(BUILD_DIR)/$$fixture.peak8.txt; \
		test -s $(BUILD_DIR)/$$fixture.peak1.txt && cmp $(BUILD_DIR)/$$fixture.peak1.txt $(BUILD_DIR)/$$fixture.peak8.txt || { echo "$$fixture: peak memory grows with iterations"; exit 1; }; \
		echo "native memory constant: $$(cat $(BUILD_DIR)/$$fixture.peak1.txt) for 20000 and 160000 iterations"
	@fixture=nativeCycle; \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native && $(NATIVE_LINK) || exit 1; \
		$(BUILD_DIR)/$$fixture.native > $(BUILD_DIR)/$$fixture.native.txt; test "$$?" -eq 70 || exit 1; \
		printf 'tree ok\nruntime error: strong reference cycle rejected for opcode 50\n' | cmp - $(BUILD_DIR)/$$fixture.native.txt || exit 1; \
		echo "native cycle rejected: $$fixture"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/nativeUnsupported.snl $(BUILD_DIR)/nativeUnsupported.s native > $(BUILD_DIR)/native-error.txt; then echo "expected native failure"; exit 1; fi
	grep -Fqx "unsupported opcode for native backend: 42" $(BUILD_DIR)/native-error.txt
