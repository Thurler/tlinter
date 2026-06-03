import 'dart:math';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';
import 'package:tlinter/src/annotations/reflect.dart';

/// A rule that checks whether functions and methods annotated with [TReflect]
/// actually reflect the signature they are pointing to
class FunctionSignatureReflection extends AnalysisRule {
  static const String ruleName = 'function_signature_reflection';

  static const LintCode _code = LintCode(
    ruleName,
    'Function {0} annotated with @TReflect does not match signature:\n{1}',
    severity: DiagnosticSeverity.ERROR,
  );

  FunctionSignatureReflection() :
    super(
      name: ruleName,
      description: 'Validate reflections for the TReflect annotation',
    );

  @override
  LintCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addFunctionDeclaration(this, _Visitor(this, context));
    registry.addMethodDeclaration(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  final RuleContext context;

  final TypeSystem typeSystem;

  _Visitor(this.rule, this.context) : typeSystem = context.typeSystem;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) => _visitFunction(
    node.name.lexeme,
    node.metadata,
    node.declaredFragment?.element.type,
  );

  @override
  void visitMethodDeclaration(MethodDeclaration node) => _visitFunction(
    node.name.lexeme,
    node.metadata,
    node.declaredFragment?.element.type,
  );

  void _visitFunction(
    String name,
    Iterable<Annotation> metadata,
    FunctionType? functionType,
  ) {
    // Find the TReflect annotations for the function/method
    Iterable<Annotation> reflects = metadata.where(
      (Annotation annotation) => annotation.name.name == 'TReflect',
    );
    // If no annotations or function type, there's nothing to validate
    if (reflects.isEmpty || functionType == null) {
      return;
    }
    // Validate each reflection entry
    for (Annotation annotation in reflects) {
      List<String> messages = _validateReflect(functionType, annotation);
      // If any alert messages were generated, raise a report at the annotation
      if (messages.isNotEmpty) {
        rule.reportAtNode(
          annotation,
          arguments: <String>[
            name,
            messages.map((String m) => '- $m').join('\n'),
          ],
        );
      }
    }
  }

  List<String> _validateReflect(FunctionType target, Annotation annotation) {
    List<String> messages = <String>[];
    // Make sure the annotation was initialized correctly
    NodeList<Expression>? arguments = annotation.arguments?.arguments;
    if (arguments == null || arguments.isEmpty) {
      return messages;
    }
    // Make sure this is statically typed to a function
    DartType? expected = arguments.first.staticType;
    if (expected is! FunctionType) {
      return messages;
    }
    // Check for named arguments we must ignore as a
    Set<String> ignoreNamedArguments = const <String>{};
    bool validateReturnType = true;
    for (int i = 1; i < arguments.length; i++) {
      // Make sure the typing adds up and the context is constant
      Expression namedArgument = arguments[i];
      if (
        namedArgument is! NamedExpression ||
        !namedArgument.expression.inConstantContext
      ) {
        continue;
      }
      DartObject? namedValue = namedArgument.computeConstantValue()?.value;
      switch (namedArgument.name.label.name) {
        case 'validateReturnType': validateReturnType =
            namedValue?.toBoolValue() ?? true;
        case 'ignoreNamedArguments': ignoreNamedArguments =
            namedValue?.toSetValue()?.map(
          (DartObject value) => value.toStringValue(),
        ).nonNulls.toSet() ?? const <String>{};
      }
    }
    // Otherwise, we start checking individual attributes
    // Return type must always be a subtype of the expected one - we can always
    // narrow the return type, never generalize it
    if (validateReturnType) {
      _validateSubtype(
        target.returnType,
        expected.returnType,
        messages,
        'Return type',
      );
    }
    // Every type argument present in the reflected function must be present in
    // the target. If originally bounded, the target bound must be a subtype of
    // the original bound
    int typeParameterCount = target.typeParameters.length;
    int expectedTypeParameterCount = expected.typeParameters.length;
    if (typeParameterCount < expectedTypeParameterCount) {
      messages.add(
        'Expected at least $expectedTypeParameterCount type argument(s), '
        'got $typeParameterCount',
      );
    }
    _validateTypeParameterList(
      target.typeParameters,
      expected.typeParameters,
      messages,
    );
    // The number of positional arguments must match
    int parameterCount = target.normalParameterTypes.length;
    int expectedParameterCount = expected.normalParameterTypes.length;
    if (parameterCount != expectedParameterCount) {
      messages.add(
        'Expected $expectedParameterCount positional argument(s), '
        'got $parameterCount',
      );
    }
    // For each positional argument present in both signatures, validate the
    // type hierarchy
    _validateParameterList(
      target.normalParameterTypes,
      expected.normalParameterTypes,
      messages,
      'Positional',
    );
    // The number of optional arguments must be at least the one from the
    // reflected function
    int optionalParameterCount = target.optionalParameterTypes.length;
    int expectedOptionalParameterCount = expected.optionalParameterTypes.length;
    if (optionalParameterCount < expectedOptionalParameterCount) {
      messages.add(
        'Expected at least $expectedOptionalParameterCount optional '
        'argument(s), got $optionalParameterCount',
      );
    }
    // For each optional argument present in both signatures, validate the
    // type hierarchy
    _validateParameterList(
      target.optionalParameterTypes,
      expected.optionalParameterTypes,
      messages,
      'Optional',
    );
    // Every named argument present in the reflected function must be present in
    // the target, even if that argument is optional. The "required" keyword is
    // NOT checked as a reflection that provides a default value is considered
    // valid. Validation for specific parameters can be disabled by including
    // their names in the [ignoreNamedArguments] set in the [TReflect]
    // annotation.
    for (String name in expected.namedParameterTypes.keys) {
      if (ignoreNamedArguments.contains(name)) {
        continue;
      }
      if (!target.namedParameterTypes.containsKey(name)) {
        messages.add('Named parameter $name missing from declaration');
        continue;
      }
      _validateSubtype(
        target.namedParameterTypes[name]!,
        expected.namedParameterTypes[name]!,
        messages,
        'Named argument $name type',
      );
    }
    return messages;
  }

  void _validateTypeParameterList(
    List<TypeParameterElement> target,
    List<TypeParameterElement> expected,
    List<String> messages,
  ) {
    for (int i = 0; i < min(target.length, expected.length); i++) {
      DartType? boundType = target[i].bound;
      DartType? expectedBoundType = expected[i].bound;
      // If there is no expected bound type, any bound type is a valid
      // reflection, as it complies with the restriction
      if (expectedBoundType == null) {
        continue;
      }
      // If the bound type is null when the expected one isn't, this is an
      // invalid reflection as it breaks the bound
      if (boundType == null) {
        messages.add(
          'Type argument ${i + 1} constraint dynamic is not a subtype of '
          '${expectedBoundType.getDisplayString()}',
        );
        continue;
      }
      // Otherwise, the bound type must be a subtype of the expected one
      String message = 'Type argument ${i + 1} constraint';
      _validateSubtype(boundType, expectedBoundType, messages, message);
    }
  }

  void _validateParameterList(
    List<DartType> target,
    List<DartType> expected,
    List<String> messages,
    String argumentType,
  ) {
    for (int i = 0; i < min(target.length, expected.length); i++) {
      String message = '$argumentType argument ${i + 1} type';
      _validateSubtype(target[i], expected[i], messages, message);
    }
  }

  void _validateSubtype(
    DartType target,
    DartType expected,
    List<String> messages,
    String prefix,
  ) {
    if (!_checkSubtype(target, expected)) {
      messages.add(
        '$prefix ${target.getDisplayString()} is not a subtype of '
        '${expected.getDisplayString()}',
      );
    }
  }

  bool _checkFunctionType(FunctionType target, FunctionType expected) {
    // Return type must match / be a subtype
    if (!_checkSubtype(target.returnType, expected.returnType)) {
      return false;
    }
    // Every type argument must match exactly
    if (target.typeParameters.length != expected.typeParameters.length) {
      return false;
    }
    for (int i = 0; i < target.typeParameters.length; i++) {
      DartType? targetBound = target.typeParameters[i].bound;
      DartType? expectedBound = expected.typeParameters[i].bound;
      // Both have no bounds - valid
      if (targetBound == null && expectedBound == null) {
        continue;
      }
      // Either has no bounds, but not the other - invalid
      if (targetBound == null || expectedBound == null) {
        return false;
      }
      // Both have bounds - validate strict equality
      if (!_checkSameType(targetBound, expectedBound)) {
        return false;
      }
    }
    // Every positional argument must match / be a supertype
    bool normalParametersOk = _checkSubtypeList(
      expected.normalParameterTypes,
      target.normalParameterTypes,
    );
    if (!normalParametersOk) {
      return false;
    }
    // Every optional argument must match / be a supertype
    bool optionalParametersOk = _checkSubtypeList(
      expected.optionalParameterTypes,
      target.optionalParameterTypes,
    );
    if (!optionalParametersOk) {
      return false;
    }
    // Every named argument must match / be a supertype, without extras
    if (
      target.namedParameterTypes.keys.length !=
      expected.namedParameterTypes.keys.length
    ) {
      return false;
    }
    return target.namedParameterTypes.keys.every(
      (String name) {
        return expected.namedParameterTypes.containsKey(name) &&
            _checkSubtype(
          expected.namedParameterTypes[name]!,
          target.namedParameterTypes[name]!,
        );
      },
    );
  }

  bool _checkSameFunctionType(FunctionType target, FunctionType expected) {
    // Return type must match
    if (!_checkSameType(target.returnType, expected.returnType)) {
      return false;
    }
    // Every type argument must match exactly
    if (target.typeParameters.length != expected.typeParameters.length) {
      return false;
    }
    for (int i = 0; i < target.typeParameters.length; i++) {
      DartType? targetBound = target.typeParameters[i].bound;
      DartType? expectedBound = expected.typeParameters[i].bound;
      // Both have no bounds - valid
      if (targetBound == null && expectedBound == null) {
        continue;
      }
      // Either has no bounds, but not the other - invalid
      if (targetBound == null || expectedBound == null) {
        return false;
      }
      // Both have bounds - validate strict equality
      if (!_checkSameType(targetBound, expectedBound)) {
        return false;
      }
    }
    // Every positional argument must match
    bool normalParametersOk = _checkSameTypeList(
      target.normalParameterTypes,
      expected.normalParameterTypes,
    );
    if (!normalParametersOk) {
      return false;
    }
    // Every optional argument must match / be a supertype
    bool optionalParametersOk = _checkSameTypeList(
      target.optionalParameterTypes,
      expected.optionalParameterTypes,
    );
    if (!optionalParametersOk) {
      return false;
    }
    // Every named argument must match / be a supertype, without extras
    if (
      target.namedParameterTypes.keys.length !=
      expected.namedParameterTypes.keys.length
    ) {
      return false;
    }
    return target.namedParameterTypes.keys.every(
      (String name) {
        return expected.namedParameterTypes.containsKey(name) &&
            _checkSameType(
          target.namedParameterTypes[name]!,
          expected.namedParameterTypes[name]!,
        );
      },
    );
  }

  bool _checkSubtypeList(List<DartType> target, List<DartType> expected) {
    if (target.length != expected.length) {
      return false;
    }
    for (int i = 0; i < target.length; i++) {
      if (!_checkSubtype(target[i], expected[i])) {
        return false;
      }
    }
    return true;
  }

  bool _checkSameTypeList(List<DartType> target, List<DartType> expected) {
    if (target.length != expected.length) {
      return false;
    }
    for (int i = 0; i < target.length; i++) {
      if (!_checkSameType(target[i], expected[i])) {
        return false;
      }
    }
    return true;
  }

  bool _checkSubtype(DartType target, DartType expected) {
    // If both types are a type parameter, compare their bounds instead
    if (target is TypeParameterType && expected is TypeParameterType) {
      // If non-nullability checks fail, abort
      if (!_checkNonNullableCompatibility(target, expected)) {
        return false;
      }
      return _checkSubtype(target.bound, expected.bound);
    }
    // If both types are a function type, we must validate things individually,
    // as typed parameters don't propagate to function parameters
    if (target is FunctionType && expected is FunctionType) {
      // If non-nullability checks fail, abort
      if (!_checkNonNullableCompatibility(target, expected)) {
        return false;
      }
      return _checkFunctionType(target, expected);
    }
    // If both types are parameterized, we must recursively validate each one of
    // the parameter types
    if (target is InterfaceType && expected is InterfaceType) {
      // Obviously must have the same number of type arguments
      if (target.typeArguments.length != expected.typeArguments.length) {
        return false;
      }
      bool allTypesMatch = Iterable<int>.generate(
        target.typeArguments.length,
        (int i) => i,
      ).every(
        (int i) =>
            _checkSubtype(target.typeArguments[i], expected.typeArguments[i]),
      );
      if (!allTypesMatch) {
        return false;
      }
    }
    // And finally, we resolve all types to their bounds and compare them - any
    // generics will have already been checked above
    return typeSystem.isSubtypeOf(_resolveType(target), _resolveType(expected));
  }

  bool _checkSameType(DartType target, DartType expected) {
    // If both types are a type parameter, compare their bounds instead
    if (target is TypeParameterType && expected is TypeParameterType) {
      // If non-nullability checks fail, abort
      if (!_checkNonNullableCompatibility(target, expected)) {
        return false;
      }
      return _checkSameType(target.bound, expected.bound);
    }
    // If both types are a function type, we must validate things individually,
    // as typed parameters don't propagate to function parameters
    if (target is FunctionType && expected is FunctionType) {
      // If non-nullability checks fail, abort
      if (!_checkNonNullableCompatibility(target, expected)) {
        return false;
      }
      return _checkSameFunctionType(target, expected);
    }
    // If both types are parameterized, we must recursively validate each one of
    // the parameter types
    if (target is InterfaceType && expected is InterfaceType) {
      // Obviously must have the same number of type arguments
      if (target.typeArguments.length != expected.typeArguments.length) {
        return false;
      }
      bool allTypesMatch = Iterable<int>.generate(
        target.typeArguments.length,
        (int i) => i,
      ).every(
        (int i) =>
            _checkSameType(target.typeArguments[i], expected.typeArguments[i]),
      );
      if (!allTypesMatch) {
        return false;
      }
    }
    // And finally, we check raw equality - this is achieved by making sure both
    // are subtypes of the other, since if A <= B and B <= A, then A == B
    return _checkSubtype(target, expected) && _checkSubtype(expected, target);
  }

  bool _checkNonNullableCompatibility(DartType target, DartType expected) {
    // If we expect a nullable type, then the target can be nullable or not
    // If we expect a strictly non nullable type, then the target must not be
    // nullable
    return !typeSystem.isStrictlyNonNullable(expected) || // expected nullable
        typeSystem.isStrictlyNonNullable(target); // expected + target non-null
  }

  DartType _resolveType(DartType dartType) => switch (dartType) {
    InterfaceType() => typeSystem.instantiateInterfaceToBounds(
        element: dartType.element,
        nullabilitySuffix: dartType.nullabilitySuffix,
      ),
    _ => dartType,
  };
}
