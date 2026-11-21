SNL ?= snl
BUILD_DIR ?= build/bootstrap
# `snl build` gera SnBC e empacota a VM C do snl; não é código de máquina.
COMPILER_BUNDLE := $(BUILD_DIR)/snova-bootstrap
VM_STAGE_IMAGE := $(BUILD_DIR)/vm-stage.snbc
VM_DIFF_FIXTURES := numericVm numericFlow hello vmCalls vmComposite staticMethods vmEnumMatch
NATIVE_FIXTURES := numericVm numericFlow nativeCalls
NATIVE_RUNTIME_FIXTURES := hello vmCalls vmComposite vmEquality vmStackOverflow nativeHostIo nativeMemory staticMethods vmArrayPop vmArrayPopString vmEnumMatch vmVariantValue vmMatchNoArm
# Programs that end normally must free every block before exit.
NATIVE_OWNERSHIP_FIXTURES := hello vmCalls vmComposite vmEquality nativeHostIo nativeMemory staticMethods vmArrayPop vmArrayPopString vmEnumMatch vmVariantValue
SDK_PATH = $(shell xcrun --show-sdk-path)
SDK_VERSION = $(shell xcrun --show-sdk-version)
STAGE1_IMAGE := $(BUILD_DIR)/stage1.snbc
STAGE2_IMAGE := $(BUILD_DIR)/stage2.snbc
SMOKE_SOURCE := bootstrap/fixtures/hello.snl
# Committed SnBC seed (ADR-0009): the first stage runs it with `snl run-snbc`
# instead of `snl check`/`snl build`.
SEED_IMAGE := bootstrap/seed/compiler.snbc
SEED_HASH_FILE := bootstrap/seed/compiler.snbc.sha256
SEED_STAGE1_IMAGE := $(BUILD_DIR)/seed-stage1.snbc
SEED_STAGE2_IMAGE := $(BUILD_DIR)/seed-stage2.snbc
SHA256 = $(shell command -v sha256sum > /dev/null 2>&1 && echo sha256sum || echo 'shasum -a 256')

.PHONY: bootstrap-check bootstrap-build bootstrap-self-host bootstrap-fixed-point bootstrap-seed-stage bootstrap-seed-fixed-point bootstrap-seed-refresh bootstrap-smoke bootstrap-diagnostics bootstrap-image-check bootstrap-vm bootstrap-vm-self bootstrap-native bootstrap-native-self bootstrap-library

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

# ADR-0009 slice 1: the committed seed image, run by `snl run-snbc` only,
# compiles the current sources (stage 1); stage 1 compiles them again
# (stage 2). Neither `snl check` nor `snl build` is involved in this chain.
bootstrap-seed-stage:
	mkdir -p $(BUILD_DIR)
	$(SHA256) -c $(SEED_HASH_FILE)
	SNL_OUTPUT=$(SEED_STAGE1_IMAGE) $(SNL) run-snbc $(SEED_IMAGE)
	SNL_OUTPUT=$(SEED_STAGE2_IMAGE) $(SNL) run-snbc $(SEED_STAGE1_IMAGE)

# Fixed point of the seed chain, plus a differential against the transitional
# `snl build` path: both roots must produce the same stage-1 image.
bootstrap-seed-fixed-point: bootstrap-seed-stage bootstrap-self-host
	cmp $(SEED_STAGE1_IMAGE) $(SEED_STAGE2_IMAGE)
	cmp $(SEED_STAGE1_IMAGE) $(STAGE1_IMAGE)
	@echo "seed fixed point ok: $$($(SHA256) $(SEED_STAGE1_IMAGE))"

# Replace the seed with the fixed-point image of the transitional `snl build`
# path and record its hash. Needed only when the current seed can no longer
# compile the sources (growth rule, ADR-0001); record the refresh in
# docs/roadmap/evidence.md and bootstrap/seed/README.md.
bootstrap-seed-refresh: bootstrap-fixed-point
	cp $(STAGE1_IMAGE) $(SEED_IMAGE)
	$(SHA256) $(SEED_IMAGE) > $(SEED_HASH_FILE)
	cat $(SEED_HASH_FILE)

bootstrap-smoke: bootstrap-build
	$(COMPILER_BUNDLE) $(SMOKE_SOURCE) $(BUILD_DIR)/hello.snbc
	test "$$( $(SNL) run-snbc $(BUILD_DIR)/hello.snbc)" = "snova bootstrap ok"

bootstrap-diagnostics: bootstrap-build
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidLex.snl $(BUILD_DIR)/invalidLex.snbc > $(BUILD_DIR)/lexical-error.txt; then echo "expected lexical failure"; exit 1; fi
	grep -Fqx "error[SNV1001]: lexical error at line 4, span 46..58" $(BUILD_DIR)/lexical-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidParse.snl $(BUILD_DIR)/invalidParse.snbc > $(BUILD_DIR)/parse-error.txt; then echo "expected parse failure"; exit 1; fi
	grep -Fqx "error[SNV2001]: parse error at line 5, span 59..59" $(BUILD_DIR)/parse-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidRuntimeArity.snl $(BUILD_DIR)/invalidRuntimeArity.snbc > $(BUILD_DIR)/runtime-arity-error.txt; then echo "expected runtime arity failure"; exit 1; fi
	grep -Fqx "error[SNV3001]: unsupported construct or invalid lowering at line 6, function #0" $(BUILD_DIR)/runtime-arity-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidStaticCall.snl $(BUILD_DIR)/invalidStaticCall.snbc > $(BUILD_DIR)/static-call-error.txt; then echo "expected static call failure"; exit 1; fi
	grep -Fqx "error[SNV3001]: unsupported construct or invalid lowering at line 14, function #1" $(BUILD_DIR)/static-call-error.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/typedLet.snl $(BUILD_DIR)/typedLet.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/typedLet.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidTypedLet.snl $(BUILD_DIR)/invalidTypedLet.snbc > $(BUILD_DIR)/typed-let-error.txt; then echo "expected typed let mismatch"; exit 1; fi
	grep -Fqx "error[SNV4001]: annotation type does not match initializer at line 4, span 54..55" $(BUILD_DIR)/typed-let-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidTypedAssignment.snl $(BUILD_DIR)/invalidTypedAssignment.snbc > $(BUILD_DIR)/typed-assignment-error.txt; then echo "expected typed assignment mismatch"; exit 1; fi
	grep -Fqx "error[SNV4002]: assignment type does not match local binding at line 5, span 70..71" $(BUILD_DIR)/typed-assignment-error.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/fieldAssignment.snl $(BUILD_DIR)/fieldAssignment.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/fieldAssignment.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidFieldAssignment.snl $(BUILD_DIR)/invalidFieldAssignment.snbc > $(BUILD_DIR)/field-assignment-error.txt; then echo "expected field assignment mismatch"; exit 1; fi
	grep -Fqx "error[SNV4003]: assignment type does not match field at line 9, span 129..130" $(BUILD_DIR)/field-assignment-error.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/matchExhaustive.snl $(BUILD_DIR)/matchExhaustive.snbc
	@$(SNL) run-snbc $(BUILD_DIR)/matchExhaustive.snbc; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidMatchExpression.snl $(BUILD_DIR)/invalidMatchExpression.snbc > $(BUILD_DIR)/match-expression-error.txt; then echo "expected non-exhaustive match"; exit 1; fi
	grep -Fqx 'error[SNV4004]: non-exhaustive match on `Signal`: missing variant `Wait` at line 11, span 130..135' $(BUILD_DIR)/match-expression-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidMatchStatement.snl $(BUILD_DIR)/invalidMatchStatement.snbc > $(BUILD_DIR)/match-statement-error.txt; then echo "expected non-exhaustive match"; exit 1; fi
	grep -Fqx 'error[SNV4004]: non-exhaustive match on `Signal`: missing variant `Go` at line 12, span 136..141' $(BUILD_DIR)/match-statement-error.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/immutableBindings.snl $(BUILD_DIR)/immutableBindings.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/immutableBindings.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidImmutableLet.snl $(BUILD_DIR)/invalidImmutableLet.snbc > $(BUILD_DIR)/immutable-let-error.txt; then echo "expected immutable binding failure"; exit 1; fi
	grep -Fqx "error[SNV4005]: cannot assign to immutable binding at line 5, span 68..69" $(BUILD_DIR)/immutable-let-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidImmutableParam.snl $(BUILD_DIR)/invalidImmutableParam.snbc > $(BUILD_DIR)/immutable-param-error.txt; then echo "expected immutable parameter failure"; exit 1; fi
	grep -Fqx "error[SNV4005]: cannot assign to immutable binding at line 4, span 60..61" $(BUILD_DIR)/immutable-param-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidImmutableFor.snl $(BUILD_DIR)/invalidImmutableFor.snbc > $(BUILD_DIR)/immutable-for-error.txt; then echo "expected immutable for binding failure"; exit 1; fi
	grep -Fqx "error[SNV4005]: cannot assign to immutable binding at line 6, span 97..98" $(BUILD_DIR)/immutable-for-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidCallArity.snl $(BUILD_DIR)/invalidCallArity.snbc > $(BUILD_DIR)/call-arity-error.txt; then echo "expected arity failure"; exit 1; fi
	grep -Fqx "error[SNV4006]: expected 2 argument(s), found 1 at line 8, span 123..124" $(BUILD_DIR)/call-arity-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidMethodArity.snl $(BUILD_DIR)/invalidMethodArity.snbc > $(BUILD_DIR)/method-arity-error.txt; then echo "expected arity failure"; exit 1; fi
	grep -Fqx "error[SNV4006]: expected 1 argument(s), found 2 at line 13, span 232..233" $(BUILD_DIR)/method-arity-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/invalidConstructorArity.snl $(BUILD_DIR)/invalidConstructorArity.snbc > $(BUILD_DIR)/constructor-arity-error.txt; then echo "expected arity failure"; exit 1; fi
	grep -Fqx "error[SNV4006]: expected 2 argument(s), found 3 at line 9, span 109..110" $(BUILD_DIR)/constructor-arity-error.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/vmArrayPop.snl $(BUILD_DIR)/vmArrayPop.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmArrayPop.snbc run; test "$$?" -eq 42
	$(COMPILER_BUNDLE) bootstrap/fixtures/vmArrayPopEmpty.snl $(BUILD_DIR)/vmArrayPopEmpty.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmArrayPopEmpty.snbc run > $(BUILD_DIR)/vmArrayPopEmpty.txt; test "$$?" -eq 70
	grep -Fqx "runtime error: pop from empty array" $(BUILD_DIR)/vmArrayPopEmpty.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/vmArrayPopString.snl $(BUILD_DIR)/vmArrayPopString.snbc
	test "$$( $(COMPILER_BUNDLE) $(BUILD_DIR)/vmArrayPopString.snbc run)" = "popped"
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
	$(COMPILER_BUNDLE) bootstrap/fixtures/vmVariantValue.snl $(BUILD_DIR)/vmVariantValue.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmVariantValue.snbc run > $(BUILD_DIR)/vmVariantValue.vm.txt; test "$$?" -eq 3
	test "$$(tr '\n' ' ' < $(BUILD_DIR)/vmVariantValue.vm.txt)" = "true false true Red Amber "
	$(COMPILER_BUNDLE) bootstrap/fixtures/vmMatchNoArm.snl $(BUILD_DIR)/vmMatchNoArm.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmMatchNoArm.snbc run > $(BUILD_DIR)/vmMatchNoArm.vm.txt; test "$$?" -eq 70
	grep -Fqx "runtime error: bodyless routine trapped" $(BUILD_DIR)/vmMatchNoArm.vm.txt

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
	grep -Fqx "unsupported opcode for native backend: 54" $(BUILD_DIR)/native-error.txt
	@fixture=vmArrayPopEmpty; \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native && $(NATIVE_LINK) || exit 1; \
		$(BUILD_DIR)/$$fixture.native > $(BUILD_DIR)/$$fixture.native.txt; test "$$?" -eq 70 || exit 1; \
		grep -Fqx "runtime error: pop from empty array" $(BUILD_DIR)/$$fixture.native.txt

# N3: assemble the compiler's ordered source modules, compile that source to
# native assembly, then use the generated executable for two further builds.
# The assembly is the fixed-point artifact; Mach-O UUID/signature are not
# compared. `as` and `ld` remain host toolchain dependencies (N4 is separate).
NATIVE_COMPILER_SOURCES := unit lex parse parseDecl emit emitExpr emitStmt runtime imageReader imageCode vmValue vmText vmString vmOps vmExec vmDecode vmFast vmFrame vmLoad nativeImage nativeRoles nativeAssembly nativeSlot nativeOwnership nativeValueEmitter nativeInstructionEmitter nativeBoundary nativeBackend sourceJoin compiler scopeParse scopeEmit scopeMatch matchCheck
NATIVE_COMPILER_SOURCE := $(BUILD_DIR)/compiler-joined.snl
NATIVE_COMPILER_ASSEMBLY := $(BUILD_DIR)/compiler-native.s
NATIVE_COMPILER_BINARY := $(BUILD_DIR)/compiler-native

bootstrap-native-self: bootstrap-build
	mkdir -p $(BUILD_DIR)
	printf 'package snova.compiler\n\n' > $(NATIVE_COMPILER_SOURCE)
	@for module in $(NATIVE_COMPILER_SOURCES); do sed '/^package /d; /^import /d' bootstrap/src/$$module.snl >> $(NATIVE_COMPILER_SOURCE); done
	$(COMPILER_BUNDLE) $(NATIVE_COMPILER_SOURCE) $(NATIVE_COMPILER_ASSEMBLY) native
	as -arch arm64 $(NATIVE_COMPILER_ASSEMBLY) -o $(BUILD_DIR)/compiler-native.o
	ld -arch arm64 -platform_version macos $(SDK_VERSION) $(SDK_VERSION) -syslibroot $(SDK_PATH) -lSystem -e _main $(BUILD_DIR)/compiler-native.o -o $(NATIVE_COMPILER_BINARY)
	$(NATIVE_COMPILER_BINARY) $(NATIVE_COMPILER_SOURCE) $(BUILD_DIR)/compiler-native-stage2.s native
	cmp $(NATIVE_COMPILER_ASSEMBLY) $(BUILD_DIR)/compiler-native-stage2.s
	as -arch arm64 $(BUILD_DIR)/compiler-native-stage2.s -o $(BUILD_DIR)/compiler-native-stage2.o
	ld -arch arm64 -platform_version macos $(SDK_VERSION) $(SDK_VERSION) -syslibroot $(SDK_PATH) -lSystem -e _main $(BUILD_DIR)/compiler-native-stage2.o -o $(BUILD_DIR)/compiler-native-stage2
	$(BUILD_DIR)/compiler-native-stage2 $(NATIVE_COMPILER_SOURCE) $(BUILD_DIR)/compiler-native-stage3.s native
	cmp $(BUILD_DIR)/compiler-native-stage2.s $(BUILD_DIR)/compiler-native-stage3.s

# Snova data-structure library (bootstrap/library): each fixture is joined
# with the library in dependency order (the seed resolves a field type only
# when its class was declared earlier) and must match `snl run-snbc`. The
# library uses static methods, so for now it serves programs compiled by the
# Snova compiler, not the compiler built by `snl build` v0.3.0. Each fixture
# also runs natively and must free every block before exit.
LIBRARY_SOURCES := intCell intArray binarySearch linearSearch sorting binaryHeap treeNode binaryTree mapEntry intMap
LIBRARY_FIXTURES := librarySearch libraryBinaryHeap libraryBinaryTree librarySorting libraryIntMap

bootstrap-library: bootstrap-build
	@for fixture in $(LIBRARY_FIXTURES); do \
		joined=$(BUILD_DIR)/$$fixture.joined.snl; \
		cat bootstrap/fixtures/$$fixture.snl > $$joined; \
		for name in $(LIBRARY_SOURCES); do printf '\n' >> $$joined; grep -v '^package ' bootstrap/library/$$name.snl >> $$joined; done; \
		$(SNL) check $$joined > /dev/null || exit 1; \
		$(COMPILER_BUNDLE) $$joined $(BUILD_DIR)/$$fixture.snbc || exit 1; \
		$(SNL) run-snbc $(BUILD_DIR)/$$fixture.snbc > $(BUILD_DIR)/$$fixture.ref.txt; referenceExit=$$?; \
		$(COMPILER_BUNDLE) $(BUILD_DIR)/$$fixture.snbc run > $(BUILD_DIR)/$$fixture.vm.txt; vmExit=$$?; \
		test "$$referenceExit" -eq "$$vmExit" || { echo "$$fixture: exit $$vmExit != $$referenceExit"; exit 1; }; \
		cmp $(BUILD_DIR)/$$fixture.ref.txt $(BUILD_DIR)/$$fixture.vm.txt || exit 1; \
		echo "library ok: $$fixture (exit $$vmExit)"; \
		$(COMPILER_BUNDLE) $$joined $(BUILD_DIR)/$$fixture.s native || exit 1; \
		$(NATIVE_LINK) || exit 1; \
		SNOVA_MEMORY_REPORT=1 $(BUILD_DIR)/$$fixture.native > $(BUILD_DIR)/$$fixture.native.txt 2> $(BUILD_DIR)/$$fixture.memory.txt; nativeExit=$$?; \
		test "$$nativeExit" -eq "$$vmExit" || { echo "$$fixture: native exit $$nativeExit != $$vmExit"; exit 1; }; \
		cmp $(BUILD_DIR)/$$fixture.native.txt $(BUILD_DIR)/$$fixture.vm.txt || exit 1; \
		grep -q "live blocks 0, live bytes 0" $(BUILD_DIR)/$$fixture.memory.txt || { echo "$$fixture: memory still live at exit"; exit 1; }; \
		echo "library native ok: $$fixture (exit $$nativeExit, zero live blocks)"; \
	done
