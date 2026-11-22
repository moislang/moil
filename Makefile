SNL ?= snl
BUILD_DIR ?= build/bootstrap
SNOVA_RELEASE_VERSION ?= 0.1.0-preview.1
# `snl build` gera SnBC e empacota a VM C do snl; não é código de máquina.
COMPILER_BUNDLE := $(BUILD_DIR)/snova-bootstrap
ifeq ($(OS),Windows_NT)
COMPILER_BUNDLE := $(BUILD_DIR)/snova-bootstrap.exe
endif
VM_STAGE_IMAGE := $(BUILD_DIR)/vm-stage.snbc
VM_DIFF_FIXTURES := NumericVm NumericFlow Hello VmCalls VmComposite StaticMethods
NATIVE_FIXTURES := NumericVm NumericFlow NativeCalls
NATIVE_RUNTIME_FIXTURES := Hello VmCalls VmComposite VmEquality VmStackOverflow NativeHostIo NativeMemory StaticMethods VmArrayPop VmArrayPopString
# Programs that end normally must free every block before exit.
NATIVE_OWNERSHIP_FIXTURES := Hello VmCalls VmComposite VmEquality NativeHostIo NativeMemory StaticMethods VmArrayPop VmArrayPopString
SDK_PATH = $(shell xcrun --show-sdk-path)
SDK_VERSION = $(shell xcrun --show-sdk-version)
STAGE1_IMAGE := $(BUILD_DIR)/stage1.snbc
STAGE2_IMAGE := $(BUILD_DIR)/stage2.snbc
SMOKE_SOURCE := bootstrap/fixtures/Hello.snl

.PHONY: bootstrap-check bootstrap-build bootstrap-self-host bootstrap-fixed-point bootstrap-smoke bootstrap-diagnostics bootstrap-image-check bootstrap-vm bootstrap-vm-self bootstrap-native bootstrap-native-self bootstrap-native-linux-aarch64 bootstrap-native-linux-aarch64-ci bootstrap-cli-linux-x86_64 bootstrap-cli-linux-aarch64 bootstrap-cli-linux-ci bootstrap-library bootstrap-oop bootstrap-oop-native bootstrap-reproducible bootstrap-prerelease

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

# OOP contracts: interface implementations are checked statically and calls
# through interface values dispatch to the concrete method in the Snova VM.
bootstrap-oop: bootstrap-build
	$(COMPILER_BUNDLE) bootstrap/fixtures/InterfaceDispatch.snl $(BUILD_DIR)/InterfaceDispatch.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/InterfaceDispatch.snbc run; test "$$?" -eq 86
	$(COMPILER_BUNDLE) bootstrap/fixtures/TraitDispatch.snl $(BUILD_DIR)/TraitDispatch.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/TraitDispatch.snbc run; test "$$?" -eq 86
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InterfaceMissingMethod.snl $(BUILD_DIR)/InterfaceMissingMethod.snbc > $(BUILD_DIR)/interface-missing.txt; then echo "expected missing interface method"; exit 1; fi
	grep -Fqx "error[SNV5001]: type does not satisfy declared contract at line 4, span 72..76" $(BUILD_DIR)/interface-missing.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InterfaceWrongSignature.snl $(BUILD_DIR)/InterfaceWrongSignature.snbc > $(BUILD_DIR)/interface-signature.txt; then echo "expected interface signature mismatch"; exit 1; fi
	grep -Fqx "error[SNV5001]: type does not satisfy declared contract at line 4, span 72..76" $(BUILD_DIR)/interface-signature.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/TraitMissingMethod.snl $(BUILD_DIR)/TraitMissingMethod.snbc > $(BUILD_DIR)/trait-missing.txt; then echo "expected missing trait method"; exit 1; fi
	grep -Fqx "error[SNV5001]: type does not satisfy declared contract at line 4, span 68..72" $(BUILD_DIR)/trait-missing.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/TraitWrongArity.snl $(BUILD_DIR)/TraitWrongArity.snbc > $(BUILD_DIR)/trait-arity.txt; then echo "expected trait arity mismatch"; exit 1; fi
	grep -Fqx "error[SNV5001]: type does not satisfy declared contract at line 4, span 68..72" $(BUILD_DIR)/trait-arity.txt

# Native interface and trait calls use a type-id indexed dispatch table.
bootstrap-oop-native: bootstrap-build
	@for fixture in InterfaceDispatch TraitDispatch; do \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native || exit 1; \
		as -arch arm64 $(BUILD_DIR)/$$fixture.s -o $(BUILD_DIR)/$$fixture.o || exit 1; \
		ld -arch arm64 -platform_version macos $(SDK_VERSION) $(SDK_VERSION) -syslibroot $(SDK_PATH) -lSystem -e _main $(BUILD_DIR)/$$fixture.o -o $(BUILD_DIR)/$$fixture.native || exit 1; \
		$(BUILD_DIR)/$$fixture.native; status=$$?; test "$$status" -eq 86 || { echo "$$fixture: expected exit 86, got $$status"; exit 1; }; \
		echo "native oop dispatch ok: $$fixture (exit $$status)"; \
	done

bootstrap-diagnostics: bootstrap-build
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidLex.snl $(BUILD_DIR)/invalidLex.snbc > $(BUILD_DIR)/lexical-error.txt; then echo "expected lexical failure"; exit 1; fi
	grep -Fqx "error[SNV1001]: lexical error at line 4, span 46..58" $(BUILD_DIR)/lexical-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidParse.snl $(BUILD_DIR)/invalidParse.snbc > $(BUILD_DIR)/parse-error.txt; then echo "expected parse failure"; exit 1; fi
	grep -Fqx "error[SNV2001]: parse error at line 5, span 59..59" $(BUILD_DIR)/parse-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidRuntimeArity.snl $(BUILD_DIR)/invalidRuntimeArity.snbc > $(BUILD_DIR)/runtime-arity-error.txt; then echo "expected runtime arity failure"; exit 1; fi
	grep -Fqx "error[SNV3001]: unsupported construct or invalid lowering at line 8, function #0" $(BUILD_DIR)/runtime-arity-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidStaticCall.snl $(BUILD_DIR)/invalidStaticCall.snbc > $(BUILD_DIR)/static-call-error.txt; then echo "expected static call failure"; exit 1; fi
	grep -Fqx "error[SNV3001]: unsupported construct or invalid lowering at line 15, function #1" $(BUILD_DIR)/static-call-error.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/TypedLet.snl $(BUILD_DIR)/typedLet.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/typedLet.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidTypedLet.snl $(BUILD_DIR)/invalidTypedLet.snbc > $(BUILD_DIR)/typed-let-error.txt; then echo "expected typed let mismatch"; exit 1; fi
	grep -Fqx "error[SNV4001]: annotation type does not match initializer at line 4, span 54..55" $(BUILD_DIR)/typed-let-error.txt
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidTypedAssignment.snl $(BUILD_DIR)/invalidTypedAssignment.snbc > $(BUILD_DIR)/typed-assignment-error.txt; then echo "expected typed assignment mismatch"; exit 1; fi
	grep -Fqx "error[SNV4002]: assignment type does not match local binding at line 5, span 70..71" $(BUILD_DIR)/typed-assignment-error.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/FieldAssignment.snl $(BUILD_DIR)/fieldAssignment.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/fieldAssignment.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidFieldAssignment.snl $(BUILD_DIR)/invalidFieldAssignment.snbc > $(BUILD_DIR)/field-assignment-error.txt; then echo "expected field assignment mismatch"; exit 1; fi
	grep -Fqx "error[SNV4003]: assignment type does not match field at line 9, span 129..130" $(BUILD_DIR)/field-assignment-error.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmArrayPop.snl $(BUILD_DIR)/vmArrayPop.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmArrayPop.snbc run; test "$$?" -eq 42
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmArrayPopEmpty.snl $(BUILD_DIR)/vmArrayPopEmpty.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmArrayPopEmpty.snbc run > $(BUILD_DIR)/vmArrayPopEmpty.txt; test "$$?" -eq 70
	grep -Fqx "runtime error: pop from empty array" $(BUILD_DIR)/vmArrayPopEmpty.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmArrayPopString.snl $(BUILD_DIR)/vmArrayPopString.snbc
	test "$$( $(COMPILER_BUNDLE) $(BUILD_DIR)/vmArrayPopString.snbc run)" = "popped"
	$(COMPILER_BUNDLE) bootstrap/fixtures/WarnMismatch.snl $(BUILD_DIR)/warnMismatch.snbc > $(BUILD_DIR)/warn-mismatch.txt
	printf 'warning[SNW0001]: comparison between different types at line 10\nwarning[SNW0001]: comparison between different types at line 13\n' | cmp - $(BUILD_DIR)/warn-mismatch.txt
	$(COMPILER_BUNDLE) bootstrap/fixtures/WarnCompare.snl $(BUILD_DIR)/warnCompare.snbc > $(BUILD_DIR)/warn-compare.txt
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
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmEquality.snl $(BUILD_DIR)/vmEquality.snbc
	test "$$( $(COMPILER_BUNDLE) $(BUILD_DIR)/vmEquality.snbc run | tr '\n' ' ')" = "true true true true true "
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmHostText.snl $(BUILD_DIR)/vmHostText.snbc
	test "$$( SNOVA_FIXTURE_TEXT=probe SNOVA_FIXTURE_OUTPUT=$(BUILD_DIR)/vmHostText.txt $(COMPILER_BUNDLE) $(BUILD_DIR)/vmHostText.snbc run extra | tr '\n' ' ')" = "true true true "
	test "$$(cat $(BUILD_DIR)/vmHostText.txt)" = "probe"
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmStackOverflow.snl $(BUILD_DIR)/vmStackOverflow.snbc
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
	@fixture=VmHostText; printf stale > $(BUILD_DIR)/vmHostText.txt; \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native && $(NATIVE_LINK) || exit 1; \
		SNOVA_FIXTURE_TEXT=probe SNOVA_FIXTURE_OUTPUT=$(BUILD_DIR)/vmHostText.txt $(BUILD_DIR)/$$fixture.native extra > $(BUILD_DIR)/$$fixture.native.txt; test "$$?" -eq 1 || exit 1; \
		test "$$(tr '\n' ' ' < $(BUILD_DIR)/$$fixture.native.txt)" = "true true true " || exit 1; \
		test "$$(cat $(BUILD_DIR)/vmHostText.txt)" = "probe" || exit 1; \
		echo "native host text ok: $$fixture (exit 1)"
	@for fixture in $(NATIVE_OWNERSHIP_FIXTURES); do \
		SNOVA_MEMORY_REPORT=1 $(BUILD_DIR)/$$fixture.native alpha beta 2>&1 > /dev/null | grep -q "live blocks 0, live bytes 0" || { echo "$$fixture: memory still live at exit"; exit 1; }; \
	done; echo "native ownership ok: zero live blocks at exit"
	@fixture=NativeMemory; \
		SNOVA_MEMORY_REPORT=1 $(BUILD_DIR)/$$fixture.native a 2>&1 > /dev/null | grep -o "peak bytes [0-9]*" > $(BUILD_DIR)/$$fixture.peak1.txt; \
		SNOVA_MEMORY_REPORT=1 $(BUILD_DIR)/$$fixture.native a a a a a a a a 2>&1 > /dev/null | grep -o "peak bytes [0-9]*" > $(BUILD_DIR)/$$fixture.peak8.txt; \
		test -s $(BUILD_DIR)/$$fixture.peak1.txt && cmp $(BUILD_DIR)/$$fixture.peak1.txt $(BUILD_DIR)/$$fixture.peak8.txt || { echo "$$fixture: peak memory grows with iterations"; exit 1; }; \
		echo "native memory constant: $$(cat $(BUILD_DIR)/$$fixture.peak1.txt) for 20000 and 160000 iterations"
	@fixture=NativeCycle; \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native && $(NATIVE_LINK) || exit 1; \
		$(BUILD_DIR)/$$fixture.native > $(BUILD_DIR)/$$fixture.native.txt; test "$$?" -eq 70 || exit 1; \
		printf 'tree ok\nruntime error: strong reference cycle rejected for opcode 50\n' | cmp - $(BUILD_DIR)/$$fixture.native.txt || exit 1; \
		echo "native cycle rejected: $$fixture"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/NativeUnsupported.snl $(BUILD_DIR)/nativeUnsupported.s native > $(BUILD_DIR)/native-error.txt; then echo "expected native failure"; exit 1; fi
	grep -Fqx "unsupported opcode for native backend: 42" $(BUILD_DIR)/native-error.txt
	@fixture=VmArrayPopEmpty; \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native && $(NATIVE_LINK) || exit 1; \
		$(BUILD_DIR)/$$fixture.native > $(BUILD_DIR)/$$fixture.native.txt; test "$$?" -eq 70 || exit 1; \
		grep -Fqx "runtime error: pop from empty array" $(BUILD_DIR)/$$fixture.native.txt

# N3: assemble the compiler's ordered source modules, compile that source to
# native assembly, then use the generated executable for two further builds.
# The assembly is the fixed-point artifact; Mach-O UUID/signature are not
# compared. `as` and `ld` remain host toolchain dependencies (N4 is separate).
NATIVE_COMPILER_SOURCES := Unit Lex Parse ParseDecl Emit EmitExpr EmitStmt Runtime ImageReader ImageCode VmValue VmText VmString VmOps VmExec VmDecode VmFast VmFrame VmLoad NativeImage NativeRoles NativeAssembly NativeSlot NativeOwnership ProcessorArchitecture OperatingSystemRuntime CallingConvention ExecutableFormat NativeToolchain NativeValueEmitter NativeInstructionEmitter NativeBoundary NativeTargetResolver NativeBackend SourceJoin Compiler ScopeParse ScopeEmit ScopeMatch
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

# Runs seed build, ELF assembly/linking, native-vs-VM fixtures and compiler
# self-host inside the pinned Linux ARM64 container used by CI.
LINUX_ARM64_IMAGE ?= snova-linux-aarch64:ci
LINUX_AMD64_IMAGE ?= snova-linux-x86_64:ci
bootstrap-cli-linux-x86_64:
	docker build --platform linux/amd64 -f ci/linux-amd64.Dockerfile -t $(LINUX_AMD64_IMAGE) ci
	docker run --rm --platform linux/amd64 -v "$(CURDIR):/workspace" -w /workspace $(LINUX_AMD64_IMAGE) make bootstrap-cli-linux-ci

bootstrap-cli-linux-aarch64:
	docker build --platform linux/arm64 -f ci/linux-aarch64.Dockerfile -t $(LINUX_ARM64_IMAGE) ci
	docker run --rm --platform linux/arm64 -v "$(CURDIR):/workspace" -w /workspace $(LINUX_ARM64_IMAGE) make bootstrap-cli-linux-ci bootstrap-native-linux-aarch64-ci

bootstrap-cli-linux-ci: bootstrap-build
	$(MAKE) -j1 bootstrap-smoke bootstrap-fixed-point bootstrap-vm bootstrap-oop

bootstrap-native-linux-aarch64:
	$(MAKE) bootstrap-cli-linux-aarch64

bootstrap-native-linux-aarch64-ci: bootstrap-build
	python3 scripts/test-native-linux-aarch64.py --compiler $(COMPILER_BUNDLE) --build-dir $(BUILD_DIR)

# Runs the VM and native self-host gates twice from separate source snapshots
# and clean output trees, then records source/toolchain/artifact hashes.
bootstrap-reproducible:
	SNL=$(SNL) python3 scripts/bootstrap-reproducible.py

# Complete the local release gates serially because they share BUILD_DIR.
# This assembles a local artifact only; publishing remains a separate action.
bootstrap-prerelease:
	@set -e; for gate in bootstrap-check bootstrap-smoke bootstrap-image-check bootstrap-vm bootstrap-diagnostics bootstrap-oop bootstrap-native bootstrap-oop-native bootstrap-library bootstrap-fixed-point bootstrap-vm-self bootstrap-native-self bootstrap-reproducible; do \
		$(MAKE) -j1 --no-print-directory $$gate; \
	done
	python3 scripts/package-prerelease.py $(SNOVA_RELEASE_VERSION)

# Snova data-structure library (bootstrap/library): each fixture is joined
# with the library in dependency order (the seed resolves a field type only
# when its class was declared earlier) and must match `snl run-snbc`. The
# library uses static methods, so for now it serves programs compiled by the
# Snova compiler, not the compiler built by `snl build` v0.3.0. Each fixture
# also runs natively and must free every block before exit.
LIBRARY_SOURCES := IntCell IntArray BinarySearch LinearSearch Sorting BinaryHeap TreeNode BinaryTree MapEntry IntMap
LIBRARY_FIXTURES := LibrarySearch LibraryBinaryHeap LibraryBinaryTree LibrarySorting LibraryIntMap

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
