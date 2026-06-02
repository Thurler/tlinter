/// An annotation that indicates that this function/method must reflect the
/// [target] [Function]'s signature.
class TReflect {
  /// The target function to reflect
  final Function target;

  /// Whether the return type will be checked in the reflection or not
  final bool validateReturnType;

  /// The named arguments to skip when validating the reflection
  ///
  /// By including a non-empty value in this field, the developer is responsible
  /// for ensuring the reflection coupling of the provided fields.
  final Set<String> ignoreNamedArguments;

  const TReflect(
    this.target, {
    this.ignoreNamedArguments = const <String>{},
    this.validateReturnType = true,
  });
}
