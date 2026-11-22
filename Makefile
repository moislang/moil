SNL ?= snl
BUILD_DIR ?= build/bootstrap
SNOVA_RELEASE_VERSION ?= 0.1.0-preview.1
# `snl build` gera SnBC e empacota a VM C do snl; não é código de máquina.
COMPILER_BUNDLE := $(BUILD_DIR)/snova-bootstrap
ifeq ($(OS),Windows_NT)
COMPILER_BUNDLE := $(BUILD_DIR)/snova-bootstrap.exe
endif
VM_STAGE_IMAGE := $(BUILD_DIR)/vm-stage.snbc
VM_DIFF_FIXTURES := NumericVm NumericFlow Hello VmCalls VmComposite StaticMethods VmEnumMatch
NATIVE_FIXTURES := NumericVm NumericFlow NativeCalls
NATIVE_RUNTIME_FIXTURES := Hello VmCalls VmComposite VmEquality VmStackOverflow NativeHostIo NativeMemory StaticMethods VmArrayPop VmArrayPopString VmEnumMatch VmVariantValue VmMatchNoArm
# Programs that end normally must free every block before exit.
NATIVE_OWNERSHIP_FIXTURES := Hello VmCalls VmComposite VmEquality NativeHostIo NativeMemory StaticMethods VmArrayPop VmArrayPopString VmEnumMatch VmVariantValue
SDK_PATH = $(shell xcrun --show-sdk-path)
SDK_VERSION = $(shell xcrun --show-sdk-version)
STAGE1_IMAGE := $(BUILD_DIR)/stage1.snbc
STAGE2_IMAGE := $(BUILD_DIR)/stage2.snbc
SMOKE_SOURCE := bootstrap/fixtures/Hello.snl
# Committed SnBC seed (ADR-0009): the first stage runs it with `snl run-snbc`
# instead of `snl check`/`snl build`.
SEED_IMAGE := bootstrap/seed/compiler.snbc
SEED_HASH_FILE := bootstrap/seed/compiler.snbc.sha256
SEED_STAGE1_IMAGE := $(BUILD_DIR)/seed-stage1.snbc
SEED_STAGE2_IMAGE := $(BUILD_DIR)/seed-stage2.snbc
SHA256 = $(shell command -v sha256sum > /dev/null 2>&1 && echo sha256sum || echo 'shasum -a 256')

# First-stage project (SPEC-0001, decision 2): `snl build --project` sees one
# directory, so the root project is staged under build/ from bootstrap/src
# plus the library modules migrated to an instance API, in dependency order
# (the order `ownSource()` in SourceJoin.snl will use once the compiler calls
# them). `snl` v0.3.0 lowers every visible module, so only migrated modules
# may be listed.
LIBRARY_ROOT_SOURCES := IntCell IntArray BinarySearch LinearSearch Sorting
LIBRARY_ROOT_FIXTURES := LibrarySearch LibrarySorting LibraryIntArray
ROOT_PROJECT := $(BUILD_DIR)/root-project

.PHONY: bootstrap-target-cli bootstrap-native-target bootstrap-native-self-target bootstrap-native-self-emit bootstrap-native-self-run bootstrap-native-linux-aarch64-emit bootstrap-native-linux-aarch64-run bootstrap-root-project bootstrap-check bootstrap-build bootstrap-self-host bootstrap-fixed-point bootstrap-seed-stage bootstrap-seed-fixed-point bootstrap-seed-refresh bootstrap-smoke bootstrap-diagnostics bootstrap-image-check bootstrap-vm bootstrap-vm-self bootstrap-native bootstrap-native-self bootstrap-library bootstrap-library-root

bootstrap-root-project:
	rm -rf $(ROOT_PROJECT)
	mkdir -p $(ROOT_PROJECT)/library
	cp bootstrap/src/*.snl $(ROOT_PROJECT)/
	@for name in $(LIBRARY_ROOT_SOURCES); do cp bootstrap/library/$$name.snl $(ROOT_PROJECT)/library/ || exit 1; done

bootstrap-check: bootstrap-root-project
	$(SNL) check --project $(ROOT_PROJECT)

bootstrap-build: bootstrap-check
	mkdir -p $(BUILD_DIR)
	$(SNL) build --project $(ROOT_PROJECT) -o $(COMPILER_BUNDLE)

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

# OOP contracts: interface implementations are checked statically and calls
# through interface values dispatch to the concrete method in the Snova VM.
bootstrap-oop: bootstrap-build
	$(COMPILER_BUNDLE) bootstrap/fixtures/InterfaceDispatch.snl $(BUILD_DIR)/InterfaceDispatch.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/InterfaceDispatch.snbc run; test "$$?" -eq 86
	$(COMPILER_BUNDLE) bootstrap/fixtures/TraitDispatch.snl $(BUILD_DIR)/TraitDispatch.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/TraitDispatch.snbc run; test "$$?" -eq 86
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InterfaceMissingMethod.snl $(BUILD_DIR)/InterfaceMissingMethod.snbc > $(BUILD_DIR)/interface-missing.txt; then echo "expected missing interface method"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/interface-missing.txt | grep -Fqx "error[SNV4012]: type does not satisfy declared contract at line 4, span 72..76"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InterfaceWrongSignature.snl $(BUILD_DIR)/InterfaceWrongSignature.snbc > $(BUILD_DIR)/interface-signature.txt; then echo "expected interface signature mismatch"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/interface-signature.txt | grep -Fqx "error[SNV4012]: type does not satisfy declared contract at line 4, span 72..76"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/TraitMissingMethod.snl $(BUILD_DIR)/TraitMissingMethod.snbc > $(BUILD_DIR)/trait-missing.txt; then echo "expected missing trait method"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/trait-missing.txt | grep -Fqx "error[SNV4012]: type does not satisfy declared contract at line 4, span 68..72"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/TraitWrongArity.snl $(BUILD_DIR)/TraitWrongArity.snbc > $(BUILD_DIR)/trait-arity.txt; then echo "expected trait arity mismatch"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/trait-arity.txt | grep -Fqx "error[SNV4012]: type does not satisfy declared contract at line 4, span 68..72"

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
	tr -d '\r' < $(BUILD_DIR)/lexical-error.txt | grep -Fqx "error[SNV1001]: lexical error at line 4, span 46..58"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidParse.snl $(BUILD_DIR)/invalidParse.snbc > $(BUILD_DIR)/parse-error.txt; then echo "expected parse failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/parse-error.txt | grep -Fqx "error[SNV2001]: parse error at line 5, span 59..59"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidRuntimeArity.snl $(BUILD_DIR)/invalidRuntimeArity.snbc > $(BUILD_DIR)/runtime-arity-error.txt; then echo "expected runtime arity failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/runtime-arity-error.txt | grep -Fqx "error[SNV3001]: unsupported construct or invalid lowering at line 6, function #0"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidStaticCall.snl $(BUILD_DIR)/invalidStaticCall.snbc > $(BUILD_DIR)/static-call-error.txt; then echo "expected static call failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/static-call-error.txt | grep -Fqx "error[SNV3001]: unsupported construct or invalid lowering at line 14, function #1"
	$(COMPILER_BUNDLE) bootstrap/fixtures/TypedLet.snl $(BUILD_DIR)/typedLet.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/typedLet.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidTypedLet.snl $(BUILD_DIR)/invalidTypedLet.snbc > $(BUILD_DIR)/typed-let-error.txt; then echo "expected typed let mismatch"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/typed-let-error.txt | grep -Fqx "error[SNV4001]: annotation type does not match initializer at line 4, span 54..55"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidTypedAssignment.snl $(BUILD_DIR)/invalidTypedAssignment.snbc > $(BUILD_DIR)/typed-assignment-error.txt; then echo "expected typed assignment mismatch"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/typed-assignment-error.txt | grep -Fqx "error[SNV4002]: assignment type does not match local binding at line 5, span 70..71"
	$(COMPILER_BUNDLE) bootstrap/fixtures/FieldAssignment.snl $(BUILD_DIR)/fieldAssignment.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/fieldAssignment.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidFieldAssignment.snl $(BUILD_DIR)/invalidFieldAssignment.snbc > $(BUILD_DIR)/field-assignment-error.txt; then echo "expected field assignment mismatch"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/field-assignment-error.txt | grep -Fqx "error[SNV4003]: assignment type does not match field at line 9, span 129..130"
	$(COMPILER_BUNDLE) bootstrap/fixtures/MatchExhaustive.snl $(BUILD_DIR)/matchExhaustive.snbc
	@$(SNL) run-snbc $(BUILD_DIR)/matchExhaustive.snbc; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidMatchExpression.snl $(BUILD_DIR)/invalidMatchExpression.snbc > $(BUILD_DIR)/match-expression-error.txt; then echo "expected non-exhaustive match"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/match-expression-error.txt | grep -Fqx 'error[SNV4004]: non-exhaustive match on `Signal`: missing variant `Wait` at line 11, span 130..135'
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidMatchStatement.snl $(BUILD_DIR)/invalidMatchStatement.snbc > $(BUILD_DIR)/match-statement-error.txt; then echo "expected non-exhaustive match"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/match-statement-error.txt | grep -Fqx 'error[SNV4004]: non-exhaustive match on `Signal`: missing variant `Go` at line 12, span 136..141'
	$(COMPILER_BUNDLE) bootstrap/fixtures/ImmutableBindings.snl $(BUILD_DIR)/immutableBindings.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/immutableBindings.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidImmutableLet.snl $(BUILD_DIR)/invalidImmutableLet.snbc > $(BUILD_DIR)/immutable-let-error.txt; then echo "expected immutable binding failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/immutable-let-error.txt | grep -Fqx "error[SNV4005]: cannot assign to immutable binding at line 5, span 68..69"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidImmutableParam.snl $(BUILD_DIR)/invalidImmutableParam.snbc > $(BUILD_DIR)/immutable-param-error.txt; then echo "expected immutable parameter failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/immutable-param-error.txt | grep -Fqx "error[SNV4005]: cannot assign to immutable binding at line 4, span 60..61"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidImmutableFor.snl $(BUILD_DIR)/invalidImmutableFor.snbc > $(BUILD_DIR)/immutable-for-error.txt; then echo "expected immutable for binding failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/immutable-for-error.txt | grep -Fqx "error[SNV4005]: cannot assign to immutable binding at line 6, span 97..98"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidCallArity.snl $(BUILD_DIR)/invalidCallArity.snbc > $(BUILD_DIR)/call-arity-error.txt; then echo "expected arity failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/call-arity-error.txt | grep -Fqx "error[SNV4006]: expected 2 argument(s), found 1 at line 8, span 123..124"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidMethodArity.snl $(BUILD_DIR)/invalidMethodArity.snbc > $(BUILD_DIR)/method-arity-error.txt; then echo "expected arity failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/method-arity-error.txt | grep -Fqx "error[SNV4006]: expected 1 argument(s), found 2 at line 13, span 232..233"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidConstructorArity.snl $(BUILD_DIR)/invalidConstructorArity.snbc > $(BUILD_DIR)/constructor-arity-error.txt; then echo "expected arity failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/constructor-arity-error.txt | grep -Fqx "error[SNV4006]: expected 2 argument(s), found 3 at line 9, span 109..110"
	$(COMPILER_BUNDLE) bootstrap/fixtures/ArgTypes.snl $(BUILD_DIR)/argTypes.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/argTypes.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidArgType.snl $(BUILD_DIR)/invalidArgType.snbc > $(BUILD_DIR)/arg-type-error.txt; then echo "expected argument type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/arg-type-error.txt | grep -Fqx "error[SNV4007]: argument type does not match parameter at line 8, span 118..119"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidConstructorType.snl $(BUILD_DIR)/invalidConstructorType.snbc > $(BUILD_DIR)/constructor-type-error.txt; then echo "expected constructor type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/constructor-type-error.txt | grep -Fqx "error[SNV4007]: argument type does not match parameter at line 8, span 97..98"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidMethodArgType.snl $(BUILD_DIR)/invalidMethodArgType.snbc > $(BUILD_DIR)/method-arg-type-error.txt; then echo "expected method argument type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/method-arg-type-error.txt | grep -Fqx "error[SNV4007]: argument type does not match parameter at line 13, span 235..236"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidPushType.snl $(BUILD_DIR)/invalidPushType.snbc > $(BUILD_DIR)/push-type-error.txt; then echo "expected push type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/push-type-error.txt | grep -Fqx "error[SNV4007]: argument type does not match parameter at line 5, span 80..81"
	$(COMPILER_BUNDLE) bootstrap/fixtures/Hello.snl $(BUILD_DIR)/hello.s native
	test -s $(BUILD_DIR)/hello.s
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidArgType.snl $(BUILD_DIR)/invalidArgType.s native > $(BUILD_DIR)/arg-type-native-error.txt; then echo "expected argument type failure in native mode"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/arg-type-native-error.txt | grep -Fqx "error[SNV4007]: argument type does not match parameter at line 8, span 118..119"
	$(COMPILER_BUNDLE) bootstrap/fixtures/OperatorTypes.snl $(BUILD_DIR)/operatorTypes.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/operatorTypes.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidBinaryType.snl $(BUILD_DIR)/invalidBinaryType.snbc > $(BUILD_DIR)/binary-type-error.txt; then echo "expected binary operator type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/binary-type-error.txt | grep -Fqx "error[SNV4008]: operator cannot be applied to these operand types at line 6, span 107..108"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidCompareType.snl $(BUILD_DIR)/invalidCompareType.snbc > $(BUILD_DIR)/compare-type-error.txt; then echo "expected comparison type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/compare-type-error.txt | grep -Fqx "error[SNV4008]: operator cannot be applied to these operand types at line 5, span 79..80"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidStringOrder.snl $(BUILD_DIR)/invalidStringOrder.snbc > $(BUILD_DIR)/string-order-error.txt; then echo "expected string ordering type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/string-order-error.txt | grep -Fqx "error[SNV4008]: operator cannot be applied to these operand types at line 4, span 57..58"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidBoolOrder.snl $(BUILD_DIR)/invalidBoolOrder.snbc > $(BUILD_DIR)/bool-order-error.txt; then echo "expected bool ordering type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/bool-order-error.txt | grep -Fqx "error[SNV4008]: operator cannot be applied to these operand types at line 4, span 58..59"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidUnaryNeg.snl $(BUILD_DIR)/invalidUnaryNeg.snbc > $(BUILD_DIR)/unary-neg-error.txt; then echo "expected unary type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/unary-neg-error.txt | grep -Fqx "error[SNV4009]: invalid operand type for unary operator at line 5, span 81..82"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidUnaryNot.snl $(BUILD_DIR)/invalidUnaryNot.snbc > $(BUILD_DIR)/unary-not-error.txt; then echo "expected unary type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/unary-not-error.txt | grep -Fqx "error[SNV4009]: invalid operand type for unary operator at line 5, span 72..73"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidIndexType.snl $(BUILD_DIR)/invalidIndexType.snbc > $(BUILD_DIR)/index-type-error.txt; then echo "expected index type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/index-type-error.txt | grep -Fqx "error[SNV4009]: index must be an integer type at line 5, span 79..80"
	$(COMPILER_BUNDLE) bootstrap/fixtures/BoolConditions.snl $(BUILD_DIR)/boolConditions.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/boolConditions.snbc run; test "$$?" -eq 42
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidIfCondition.snl $(BUILD_DIR)/invalidIfCondition.snbc > $(BUILD_DIR)/if-condition-error.txt; then echo "expected non-bool if condition"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/if-condition-error.txt | grep -Fqx "error[SNV4010]: condition must be bool at line 5, span 72..73"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/InvalidWhileCondition.snl $(BUILD_DIR)/invalidWhileCondition.snbc > $(BUILD_DIR)/while-condition-error.txt; then echo "expected non-bool while condition"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/while-condition-error.txt | grep -Fqx "error[SNV4010]: condition must be bool at line 5, span 75..76"
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmArrayPop.snl $(BUILD_DIR)/vmArrayPop.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmArrayPop.snbc run; test "$$?" -eq 42
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmArrayPopEmpty.snl $(BUILD_DIR)/vmArrayPopEmpty.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmArrayPopEmpty.snbc run > $(BUILD_DIR)/vmArrayPopEmpty.txt; test "$$?" -eq 70
	tr -d '\r' < $(BUILD_DIR)/vmArrayPopEmpty.txt | grep -Fqx "runtime error: pop from empty array"
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmArrayPopString.snl $(BUILD_DIR)/vmArrayPopString.snbc
	test "$$( $(COMPILER_BUNDLE) $(BUILD_DIR)/vmArrayPopString.snbc run)" = "popped"
	@if $(COMPILER_BUNDLE) bootstrap/fixtures/WarnMismatch.snl $(BUILD_DIR)/warnMismatch.snbc > $(BUILD_DIR)/warn-mismatch.txt; then echo "expected comparison type failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/warn-mismatch.txt | grep -Fqx "error[SNV4008]: operator cannot be applied to these operand types at line 10, span 171..172"
	$(COMPILER_BUNDLE) bootstrap/fixtures/WarnCompare.snl $(BUILD_DIR)/warnCompare.snbc > $(BUILD_DIR)/warn-compare.txt
	test ! -s $(BUILD_DIR)/warn-compare.txt
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/warnCompare.snbc run; test "$$?" -eq 7

bootstrap-image-check: bootstrap-self-host
	test "$$( $(COMPILER_BUNDLE) $(STAGE1_IMAGE))" = "valid SnBC image"
	head -c 8 $(STAGE1_IMAGE) > $(BUILD_DIR)/truncated.snbc
	@if $(COMPILER_BUNDLE) $(BUILD_DIR)/truncated.snbc > $(BUILD_DIR)/image-error.txt; then echo "expected image failure"; exit 1; fi
	tr -d '\r' < $(BUILD_DIR)/image-error.txt | grep -Fqx "invalid SnBC image"

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
	test "$$( $(COMPILER_BUNDLE) $(BUILD_DIR)/vmEquality.snbc run | tr -d '\r' | tr '\n' ' ')" = "true true true true true "
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmHostText.snl $(BUILD_DIR)/vmHostText.snbc
	@SNOVA_FIXTURE_TEXT=probe SNOVA_FIXTURE_OUTPUT=$(BUILD_DIR)/vmHostText.txt $(COMPILER_BUNDLE) $(BUILD_DIR)/vmHostText.snbc run extra > $(BUILD_DIR)/vmHostText.vm.txt 2> $(BUILD_DIR)/vmHostText.vm.err; status=$$?; \
		if [ "$$(tr -d '\r' < $(BUILD_DIR)/vmHostText.vm.txt | tr '\n' ' ')" != "true true true " ]; then \
			echo "VmHostText: exit $$status, SNOVA_FIXTURE_OUTPUT=$(BUILD_DIR)/vmHostText.txt"; \
			echo "stdout:"; cat $(BUILD_DIR)/vmHostText.vm.txt; echo "stderr:"; cat $(BUILD_DIR)/vmHostText.vm.err; \
			ls -la $(BUILD_DIR) | head -5; exit 1; \
		fi
	test "$$(tr -d '\r' < $(BUILD_DIR)/vmHostText.txt)" = "probe"
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmStackOverflow.snl $(BUILD_DIR)/vmStackOverflow.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmStackOverflow.snbc run > $(BUILD_DIR)/vmStackOverflow.vm.txt; test "$$?" -eq 70
	tr -d '\r' < $(BUILD_DIR)/vmStackOverflow.vm.txt | grep -Fqx "runtime error: Stack overflow"
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmVariantValue.snl $(BUILD_DIR)/vmVariantValue.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmVariantValue.snbc run > $(BUILD_DIR)/vmVariantValue.vm.txt; test "$$?" -eq 3
	test "$$(tr -d '\r' < $(BUILD_DIR)/vmVariantValue.vm.txt | tr '\n' ' ')" = "true false true Red Amber "
	$(COMPILER_BUNDLE) bootstrap/fixtures/VmMatchNoArm.snl $(BUILD_DIR)/vmMatchNoArm.snbc
	@$(COMPILER_BUNDLE) $(BUILD_DIR)/vmMatchNoArm.snbc run > $(BUILD_DIR)/vmMatchNoArm.vm.txt; test "$$?" -eq 70
	tr -d '\r' < $(BUILD_DIR)/vmMatchNoArm.vm.txt | grep -Fqx "runtime error: bodyless routine trapped"

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
		test "$$(tr -d '\r' < $(BUILD_DIR)/$$fixture.native.txt | tr '\n' ' ')" = "true true true " || exit 1; \
		test "$$(tr -d '\r' < $(BUILD_DIR)/vmHostText.txt)" = "probe" || exit 1; \
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
	tr -d '\r' < $(BUILD_DIR)/native-error.txt | grep -Fqx "unsupported opcode for native backend: 54"
	@fixture=VmArrayPopEmpty; \
		$(COMPILER_BUNDLE) bootstrap/fixtures/$$fixture.snl $(BUILD_DIR)/$$fixture.s native && $(NATIVE_LINK) || exit 1; \
		$(BUILD_DIR)/$$fixture.native > $(BUILD_DIR)/$$fixture.native.txt; test "$$?" -eq 70 || exit 1; \
		tr -d '\r' < $(BUILD_DIR)/$$fixture.native.txt | grep -Fqx "runtime error: pop from empty array"

# N3: assemble the compiler's ordered source modules, compile that source to
# native assembly, then use the generated executable for two further builds.
# The assembly is the fixed-point artifact; Mach-O UUID/signature are not
# compared. `as` and `ld` remain host toolchain dependencies (N4 is separate).
NATIVE_COMPILER_SOURCES := Unit Lex Parse ParseDecl Emit EmitExpr EmitStmt Runtime ImageReader ImageCode VmValue VmText VmString VmOps VmExec VmDecode VmFast VmFrame VmLoad NativeImage NativeRoles NativeAssembly NativeSlot NativeOwnership ProcessorArchitecture OperatingSystemRuntime CallingConvention ExecutableFormat NativeToolchain NativeValueEmitter NativeInstructionEmitter NativeTargetResolver NativeBoundary NativeBackend SourceJoin Compiler ScopeParse ScopeEmit ScopeMatch MatchCheck
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

LINUX_ARM64_IMAGE ?= snova-linux-aarch64:ci
LINUX_AMD64_IMAGE ?= snova-linux-x86_64:ci
# The x86_64 image uses the official snl binary. The ARM64 image has no snl:
# the host (which has snl) emits the ELF assembly and VM results, and the
# container only assembles, links and runs them, as in CI.
bootstrap-cli-linux-x86_64:
	docker build --platform linux/amd64 -f ci/linux-amd64.Dockerfile -t $(LINUX_AMD64_IMAGE) ci
	docker run --rm --platform linux/amd64 -v "$(CURDIR):/workspace" -w /workspace $(LINUX_AMD64_IMAGE) make bootstrap-cli-linux-ci

bootstrap-cli-linux-aarch64: bootstrap-native-linux-aarch64-emit
	docker build --platform linux/arm64 -f ci/linux-aarch64.Dockerfile -t $(LINUX_ARM64_IMAGE) ci
	docker run --rm --platform linux/arm64 -v "$(CURDIR):/workspace" -w /workspace $(LINUX_ARM64_IMAGE) make bootstrap-native-linux-aarch64-run

bootstrap-cli-linux-ci: bootstrap-build
	$(MAKE) -j1 bootstrap-smoke bootstrap-fixed-point bootstrap-vm bootstrap-oop bootstrap-target-cli

bootstrap-native-linux-aarch64:
	$(MAKE) bootstrap-cli-linux-aarch64

bootstrap-native-linux-aarch64-ci: bootstrap-build
	python3 scripts/test-native-linux-aarch64.py --compiler $(COMPILER_BUNDLE) --build-dir $(BUILD_DIR) --target aarch64-unknown-linux-gnu

# Split Linux AArch64 native gate for CI: the emit half runs where snl is
# available (any host), the run half on a Linux AArch64 host with binutils
# only. Output goes to build/bootstrap/native-aarch64-unknown-linux-gnu/.
LINUX_AARCH64_DIR := $(BUILD_DIR)/native-aarch64-unknown-linux-gnu
bootstrap-native-linux-aarch64-emit: bootstrap-build
	python3 scripts/test-native-linux-aarch64.py --phase emit --compiler $(COMPILER_BUNDLE) --build-dir $(LINUX_AARCH64_DIR)/fixtures --target aarch64-unknown-linux-gnu
	$(MAKE) bootstrap-native-self-emit NATIVE_TARGET=aarch64-unknown-linux-gnu

bootstrap-native-linux-aarch64-run:
	python3 scripts/test-native-linux-aarch64.py --phase run --build-dir $(LINUX_AARCH64_DIR)/fixtures
	$(MAKE) bootstrap-native-self-run NATIVE_TARGET=aarch64-unknown-linux-gnu

# Native target selection. The compiler takes the target on its command line
# (`<in.snl> <out.s> --target <triple>`, or the older `native [<triple>]`);
# the triple fixes the executable format: Mach-O for aarch64-apple-darwin,
# ELF for the Linux triples. Choose it here with NATIVE_TARGET, for example
#   make bootstrap-native-target NATIVE_TARGET=aarch64-unknown-linux-gnu
NATIVE_TARGET ?= aarch64-apple-darwin
NATIVE_TARGETS := aarch64-apple-darwin aarch64-unknown-linux-gnu x86_64-unknown-linux-gnu
NATIVE_TARGET_DIR := $(BUILD_DIR)/native-$(NATIVE_TARGET)
ifeq ($(NATIVE_TARGET),aarch64-apple-darwin)
native_assemble = as -arch arm64 $(1) -o $(2)
native_link = ld -arch arm64 -platform_version macos $(SDK_VERSION) $(SDK_VERSION) -syslibroot $(SDK_PATH) -lSystem -e _main $(1) -o $(2)
else ifeq ($(NATIVE_TARGET),aarch64-unknown-linux-gnu)
native_assemble = as $(1) -o $(2)
native_link = ld -static -e _start $(1) -o $(2)
# Known divergence (docs/roadmap/evidence.md, 2026-11-22): a stage 1 emitted
# by the SnBC compiler on a Linux host (x86_64 or AArch64) is smaller than
# the native compiler's stage 2; emitted on macOS it is identical. The native
# fixed point (stage 2 = stage 3) stays mandatory.
NATIVE_STAGE1_CHECK ?= report
endif
# `required` fails when stage 1 (SnBC compiler) differs from stage 2 (native
# compiler); `report` prints a warning instead.
NATIVE_STAGE1_CHECK ?= required

# Host-independent gate for target selection: every accepted command-line
# form emits the same assembly for a target, each triple emits its own
# object format, and malformed or unsupported targets fail with a message.
# Only assembly text is checked, so it runs on every CI host.
bootstrap-target-cli: bootstrap-build
	@dir=$(BUILD_DIR)/target-cli; mkdir -p $$dir; \
	for target in aarch64-apple-darwin aarch64-unknown-linux-gnu; do \
		$(COMPILER_BUNDLE) $(SMOKE_SOURCE) $$dir/$$target-flag.s --target $$target > /dev/null || exit 1; \
		$(COMPILER_BUNDLE) $(SMOKE_SOURCE) $$dir/$$target-native-flag.s native --target $$target > /dev/null || exit 1; \
		$(COMPILER_BUNDLE) $(SMOKE_SOURCE) $$dir/$$target-positional.s native $$target > /dev/null || exit 1; \
		cmp $$dir/$$target-flag.s $$dir/$$target-native-flag.s || exit 1; \
		cmp $$dir/$$target-flag.s $$dir/$$target-positional.s || exit 1; \
	done; \
	$(COMPILER_BUNDLE) $(SMOKE_SOURCE) $$dir/default.s native > /dev/null || exit 1; \
	cmp $$dir/default.s $$dir/aarch64-apple-darwin-flag.s || { echo "default target is not aarch64-apple-darwin"; exit 1; }; \
	grep -q '__TEXT' $$dir/aarch64-apple-darwin-flag.s || { echo "Mach-O sections missing"; exit 1; }; \
	grep -q '@PAGE' $$dir/aarch64-apple-darwin-flag.s || { echo "Mach-O relocations missing"; exit 1; }; \
	grep -q '^ *\.section \.text$$' $$dir/aarch64-unknown-linux-gnu-flag.s || { echo "ELF text section missing"; exit 1; }; \
	grep -q ':lo12:' $$dir/aarch64-unknown-linux-gnu-flag.s || { echo "ELF relocations missing"; exit 1; }; \
	if grep -q '@PAGE\|__TEXT' $$dir/aarch64-unknown-linux-gnu-flag.s; then echo "Mach-O syntax in ELF output"; exit 1; fi; \
	if $(COMPILER_BUNDLE) $(SMOKE_SOURCE) $$dir/x86.s --target x86_64-unknown-linux-gnu > $$dir/x86.txt; then echo "expected pending x86-64 backend"; exit 1; fi; \
	tr -d '\r' < $$dir/x86.txt | grep -Fqx "native target recognized but Linux x86-64 backend is not implemented" || exit 1; \
	if $(COMPILER_BUNDLE) $(SMOKE_SOURCE) $$dir/unknown.s --target sparc-sun-solaris > $$dir/unknown.txt; then echo "expected unknown target failure"; exit 1; fi; \
	tr -d '\r' < $$dir/unknown.txt | grep -Fqx "native target is unknown or unsupported" || exit 1; \
	for args in "--target" "native --target" "bogus" "--target a b"; do \
		set -- $$args; \
		$(COMPILER_BUNDLE) $(SMOKE_SOURCE) $$dir/usage.s "$$@" > $$dir/usage.txt; status=$$?; \
		test "$$status" -eq 2 || { echo "[$$args] exit $$status, expected usage error 2"; exit 1; }; \
		grep -q '^usage: ' $$dir/usage.txt || exit 1; \
	done; \
	echo "target cli ok: $(NATIVE_TARGETS)"

# Builds and runs the native fixtures and the native compiler for
# NATIVE_TARGET on a matching host (assembly and linking need its toolchain).
bootstrap-native-target: bootstrap-build
ifeq ($(NATIVE_TARGET),aarch64-apple-darwin)
	$(MAKE) bootstrap-native
else ifeq ($(NATIVE_TARGET),aarch64-unknown-linux-gnu)
	python3 scripts/test-native-linux-aarch64.py --compiler $(COMPILER_BUNDLE) --build-dir $(NATIVE_TARGET_DIR)/fixtures --target $(NATIVE_TARGET)
else
	@echo "native build for $(NATIVE_TARGET) is not available (targets with a backend: aarch64-apple-darwin aarch64-unknown-linux-gnu)"; exit 1
endif
	$(MAKE) bootstrap-native-self-target NATIVE_TARGET=$(NATIVE_TARGET)

# The snl compiler itself as a native executable for NATIVE_TARGET: stage 1
# is compiled by the SnBC compiler, stages 2 and 3 by the native compiler
# just built; their assembly must be identical (same rule as N3).
# The two halves can run on different hosts: -emit needs snl (any host),
# -run needs only the target's as/ld (CI runs it on a Linux ARM64 runner).
bootstrap-native-self-target: bootstrap-native-self-emit
	$(MAKE) bootstrap-native-self-run NATIVE_TARGET=$(NATIVE_TARGET)

bootstrap-native-self-emit: bootstrap-build
	mkdir -p $(NATIVE_TARGET_DIR)
	printf 'package snova.compiler\n\n' > $(NATIVE_TARGET_DIR)/compiler-joined.snl
	@for module in $(NATIVE_COMPILER_SOURCES); do sed '/^package /d; /^import /d' bootstrap/src/$$module.snl >> $(NATIVE_TARGET_DIR)/compiler-joined.snl; done
	$(COMPILER_BUNDLE) $(NATIVE_TARGET_DIR)/compiler-joined.snl $(NATIVE_TARGET_DIR)/stage1.s --target $(NATIVE_TARGET)

bootstrap-native-self-run:
	@test -n '$(call native_link,in,out)' || { echo "native compiler build for $(NATIVE_TARGET) is not available"; exit 1; }
	@test -f $(NATIVE_TARGET_DIR)/stage1.s || { echo "missing $(NATIVE_TARGET_DIR)/stage1.s; run bootstrap-native-self-emit first"; exit 1; }
	$(call native_assemble,$(NATIVE_TARGET_DIR)/stage1.s,$(NATIVE_TARGET_DIR)/stage1.o)
	$(call native_link,$(NATIVE_TARGET_DIR)/stage1.o,$(NATIVE_TARGET_DIR)/snl-stage1)
	$(NATIVE_TARGET_DIR)/snl-stage1 $(NATIVE_TARGET_DIR)/compiler-joined.snl $(NATIVE_TARGET_DIR)/stage2.s --target $(NATIVE_TARGET)
	@if cmp -s $(NATIVE_TARGET_DIR)/stage1.s $(NATIVE_TARGET_DIR)/stage2.s; then \
		echo "stage1.s == stage2.s"; \
	elif [ "$(NATIVE_STAGE1_CHECK)" = report ]; then \
		echo "warning: stage1.s (SnBC compiler) differs from stage2.s (native compiler) for $(NATIVE_TARGET); known divergence, see docs/roadmap/evidence.md"; \
	else \
		cmp $(NATIVE_TARGET_DIR)/stage1.s $(NATIVE_TARGET_DIR)/stage2.s; \
	fi
	$(call native_assemble,$(NATIVE_TARGET_DIR)/stage2.s,$(NATIVE_TARGET_DIR)/stage2.o)
	$(call native_link,$(NATIVE_TARGET_DIR)/stage2.o,$(NATIVE_TARGET_DIR)/snl)
	$(NATIVE_TARGET_DIR)/snl $(NATIVE_TARGET_DIR)/compiler-joined.snl $(NATIVE_TARGET_DIR)/stage3.s --target $(NATIVE_TARGET)
	cmp $(NATIVE_TARGET_DIR)/stage2.s $(NATIVE_TARGET_DIR)/stage3.s
	@echo "native snl ok for $(NATIVE_TARGET): $(NATIVE_TARGET_DIR)/snl"

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
# when its class was declared earlier) and must match `snl run-snbc`. Most of
# the library still uses static methods, so it serves programs compiled by the
# Snova compiler, not the compiler built by `snl build` v0.3.0; the modules
# migrated to an instance API are gated by `bootstrap-library-root`. Each
# fixture also runs natively and must free every block before exit.
LIBRARY_SOURCES := IntCell IntArray BinarySearch LinearSearch Sorting BinaryHeap TreeNode BinaryTree MapEntry IntMap
LIBRARY_FIXTURES := LibrarySearch LibraryBinaryHeap LibraryBinaryTree LibrarySorting LibraryIntMap LibraryIntArray

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

# Library modules with an instance API (ADR-0007), which `snl build` v0.3.0,
# the current root, can build. Each fixture is joined with these modules only.
# The `snl build` executable, `snl run-snbc` and the Snova executor must agree
# on stdout and exit status for the image compiled by the Snova compiler, and
# match bootstrap/fixtures/expected/<fixture>.stdout and .status, captured from
# the fixture before its migration (SPEC-0001). Needs no native toolchain, so
# it runs on every host with `snl`. LIBRARY_ROOT_SOURCES and
# LIBRARY_ROOT_FIXTURES are defined at the top, next to the root project.
bootstrap-library-root: bootstrap-build
	@for fixture in $(LIBRARY_ROOT_FIXTURES); do \
		joined=$(BUILD_DIR)/$$fixture.root.snl; \
		cat bootstrap/fixtures/$$fixture.snl > $$joined; \
		for name in $(LIBRARY_ROOT_SOURCES); do printf '\n' >> $$joined; grep -v '^package ' bootstrap/library/$$name.snl >> $$joined; done; \
		$(SNL) check $$joined > /dev/null || exit 1; \
		$(SNL) build $$joined -o $(BUILD_DIR)/$$fixture.root > /dev/null || exit 1; \
		$(BUILD_DIR)/$$fixture.root > $(BUILD_DIR)/$$fixture.root.txt; rootExit=$$?; \
		$(COMPILER_BUNDLE) $$joined $(BUILD_DIR)/$$fixture.root.snbc || exit 1; \
		$(SNL) run-snbc $(BUILD_DIR)/$$fixture.root.snbc > $(BUILD_DIR)/$$fixture.root.ref.txt; referenceExit=$$?; \
		$(COMPILER_BUNDLE) $(BUILD_DIR)/$$fixture.root.snbc run > $(BUILD_DIR)/$$fixture.root.vm.txt; vmExit=$$?; \
		test "$$rootExit" -eq "$$referenceExit" -a "$$rootExit" -eq "$$vmExit" || { echo "$$fixture: root $$rootExit ref $$referenceExit vm $$vmExit"; exit 1; }; \
		cmp $(BUILD_DIR)/$$fixture.root.txt $(BUILD_DIR)/$$fixture.root.ref.txt || exit 1; \
		cmp $(BUILD_DIR)/$$fixture.root.txt $(BUILD_DIR)/$$fixture.root.vm.txt || exit 1; \
		test "$$rootExit" -eq "$$(cat bootstrap/fixtures/expected/$$fixture.status)" || { echo "$$fixture: exit $$rootExit != expected $$(cat bootstrap/fixtures/expected/$$fixture.status)"; exit 1; }; \
		cmp bootstrap/fixtures/expected/$$fixture.stdout $(BUILD_DIR)/$$fixture.root.txt || { echo "$$fixture: stdout differs from expected"; exit 1; }; \
		echo "library root ok: $$fixture (exit $$rootExit, matches expected)"; \
	done
