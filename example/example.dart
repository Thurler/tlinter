import 'package:tlinter/src/annotations/reflect.dart';

//////////////
/// Example 1 - A sanity test for the most basic function ever
//////////////

void foo1() {}

@TReflect(foo1)
void bar1() {}

//////////////
/// Example 2 - The return type can be a subtype of the reflected one
//////////////

num foo2() => 1;

@TReflect(foo2)
int bar2() => 1;

//////////////
/// Example 3 - The return type should never be a supertype of the reflected one
//////////////

int foo3() => 1;

@TReflect(foo3)
num bar3() => 1;

//////////////
/// Example 4 - The return type validation should be ignored if the appropriate
/// flag is set in the annotation
//////////////

int foo4() => 1;

@TReflect(foo3, validateReturnType: false)
num bar4() => 1;

//////////////
/// Example 5 - The return type subtype check should extend to templated types
/// like Iterable and List, recursively down to every template
//////////////

Iterable<num> foo5a() => <num>[];
Iterable<Map<String, num>> foo5b() => <Map<String, num>>[];

List<int> foo5c() => <int>[];
List<Map<String, int>> foo5d() => <Map<String, int>>[];

// These 4 should fail - they implement irrelevant types

@TReflect(foo5a)
Iterable<String> bar5a0() => <String>[];

@TReflect(foo5b)
Iterable<String> bar5b0() => <String>[];

@TReflect(foo5c)
List<String> bar5c0() => <String>[];

@TReflect(foo5d)
List<String> bar5d0() => <String>[];

// These 6 should be ok - they always increase type specificity

@TReflect(foo5a)
List<num> bar5a1() => <int>[];

@TReflect(foo5a)
Iterable<int> bar5a2() => <int>[];

@TReflect(foo5a)
List<int> bar5a3() => <int>[];

@TReflect(foo5b)
List<Map<String, num>> bar5b1() => <Map<String, num>>[];

@TReflect(foo5b)
Iterable<Map<String, int>> bar5b2() => <Map<String, int>>[];

@TReflect(foo5b)
List<Map<String, int>> bar5b3() => <Map<String, int>>[];

// These 6 should fail - they decrease type specificity

@TReflect(foo5c)
List<num> bar5c1() => <num>[];

@TReflect(foo5c)
Iterable<int> bar5c2() => <int>[];

@TReflect(foo5c)
Iterable<num> bar5c3() => <num>[];

@TReflect(foo5d)
List<Map<String, num>> bar5d1() => <Map<String, num>>[];

@TReflect(foo5d)
Iterable<Map<String, int>> bar5d2() => <Map<String, int>>[];

@TReflect(foo5d)
Iterable<Map<String, num>> bar5d3() => <Map<String, num>>[];

//////////////
/// Example 6 - Templated types for the functions should also be checked, but
/// according to their constraints. Just like regular types, types can always be
/// narrowed, never generalized. This also extends to the return type.
//////////////

void foo6a<T>() {}
void foo6b<T extends num>() {}
void foo6c<T extends int>() {}
void foo6d<S extends num, T extends Iterable<S>>() {}
void foo6e<S extends int, T extends List<S>>() {}
S? foo6f<S extends num, T extends Iterable<S>>() => null;
S? foo6g<S extends int, T extends List<S>>() => null;

// These should be ok - they always increase or match type specificity, even if
// the actual letter changes

@TReflect(foo6a)
void bar6a<U>() {}

@TReflect(foo6b)
void bar6b<U extends int>() {}

@TReflect(foo6d)
void bar6d<W extends int, U extends List<W>>() {}

@TReflect(foo6f)
W? bar6f<W extends int, U extends List<W>>() => null;

// These should not be ok - they drop constraints or change to irrelevant types

@TReflect(foo6c)
void bar6c0<T>() {}

@TReflect(foo6c)
void bar6c1<T extends String>() {}

@TReflect(foo6c)
void bar6c2<T extends num>() {}

@TReflect(foo6e)
void bar6e0<S, T extends List<S>>() {}

@TReflect(foo6e)
void bar6e1<S extends num, T extends List<S>>() {}

@TReflect(foo6e)
void bar6e2<S extends int, T extends Iterable<S>>() {}

@TReflect(foo6g)
S? bar6g0<S, T extends List<S>>() => null;

@TReflect(foo6g)
S? bar6g1<S extends num, T extends List<S>>() => null;

@TReflect(foo6g)
S? bar6g2<S extends int, T extends Iterable<S>>() => null;

//////////////
/// Example 7 - Positional argument count must match, and types should follow
/// the same logic as the subtyping rules described above. The formal name is
/// not relevant.
//////////////

void foo7a() {}
void foo7b(num a) {}
void foo7c(int a) {}
void foo7d<T extends num>(T a) {}
void foo7e<T extends int>(T a) {}

// These should not be ok - they don't match the parameter count

@TReflect(foo7a)
void bar7a(String a) {}

@TReflect(foo7b)
void bar7b() {}

// These should be ok - they match everything, but change the parameter name

@TReflect(foo7b)
void bar7b0(num z) {}

@TReflect(foo7c)
void bar7c0(int z) {}

@TReflect(foo7d)
void bar7d0<T extends num>(T z) {}

@TReflect(foo7e)
void bar7e0<T extends int>(T z) {}

// These should not be ok - they match the count, but not the typing

@TReflect(foo7b)
void bar7b1(String z) {}

@TReflect(foo7c)
void bar7c1(num z) {}

@TReflect(foo7d)
void bar7d1<T extends String>(T z) {}

@TReflect(foo7e)
void bar7e1<T extends num>(T z) {}

//////////////
/// Example 8 - Optional argument count must not be lower, and types should
/// follow the same logic as the subtyping rules described above. The formal
/// name is not relevant, as are arguments that go beyond the original
/// function's optional arguments
//////////////

void foo8b([num? a]) {}
void foo8c([int? a]) {}
void foo8d<T extends num>([T? a]) {}
void foo8e<T extends int>([T? a]) {}

// These should not be ok - they drop from the original parameter count

@TReflect(foo8b)
void bar8b() {}

// These should be ok - they match everything, but change the parameter name or
// include more optional parameters

@TReflect(foo8b)
void bar8b0([num? z, String? y]) {}

@TReflect(foo8c)
void bar8c0([int? z]) {}

@TReflect(foo8d)
void bar8d0<T extends num>([T? z, T? t]) {}

@TReflect(foo8e)
void bar8e0<T extends int>([T? z]) {}

// These should not be ok - they match the count, but not the typing

@TReflect(foo8b)
void bar8b1([String? z]) {}

@TReflect(foo8c)
void bar8c1([num? z]) {}

@TReflect(foo8d)
void bar8d1<T extends String>([T? z]) {}

@TReflect(foo8e)
void bar8e1<T extends num>([T? z]) {}

//////////////
/// Example 9 - Named arguments must be properly mirrored, keeping the name and
/// type, following the same logic as the subtyping rules described above. Extra
/// named arguments are not validated, much like extra optional arguments
//////////////

void foo9b({num? a}) {}
void foo9c({int? a}) {}
void foo9d<T extends num>({T? a}) {}
void foo9e<T extends int>({T? a}) {}

// These should not be ok - they drop from an original named argument, or rename
// an existing one

@TReflect(foo9b)
void bar9b() {}

@TReflect(foo9c)
void bar9c({int? z}) {}

@TReflect(foo9d)
void bar9d<T extends num>({T? t}) {}

@TReflect(foo9e)
void bar9e<T extends int>({T? t}) {}

// These should be ok - they match everything, but change the parameter name or
// include more optional parameters

@TReflect(foo9b)
void bar9b0({num? a, String? y}) {}

@TReflect(foo9c)
void bar9c0({int? a}) {}

@TReflect(foo9d)
void bar9d0<T extends num>({T? a, T? t}) {}

@TReflect(foo9e)
void bar9e0<T extends int>({T? a}) {}

// These should not be ok - they match the count, but not the typing

@TReflect(foo9b)
void bar9b1({String? a}) {}

@TReflect(foo9c)
void bar9c1({num? a}) {}

@TReflect(foo9d)
void bar9d1<T extends String>({T? a}) {}

@TReflect(foo9e)
void bar9e1<T extends num>({T? a}) {}

//////////////
/// Example 10 - Named arguments validation can be omitted for specific names
/// through the ignoreNamedArguments annotation argument
//////////////

void foo10({int? a, String? b, double? c}) {}

@TReflect(foo10, ignoreNamedArguments: <String>{'b', 'c'})
void bar10({int? a, double? b}) {}

//////////////
/// Example 11 - All rules described above are applied to function parameters or
/// function returns. Some additional restrictions are imposed, however,
/// depending on which part of the function has a function parameter:
/// - For every type, the signature shape must match, meaning no extra optional
///   or named arguments are allowed
/// - Return types follow the same rules described by the examples above
/// - Template types must match exactly
/// - Positional, optional and named arguments must be a supertype instead of
///   subtypes, as the type expectation is reversed for function arguments
///   (you can pass a function that accepts num where int was expected, but not
///   one that accepts int where num was expected)
//////////////

void Function()? foo11a() => null;
num Function()? foo11b() => null;
int Function()? foo11c() => null;
Iterable<num> Function()? foo11d() => null;
List<int> Function()? foo11e() => null;
void Function<T>()? foo11f() => null;
void Function<T extends num>()? foo11g() => null;
void Function<T extends int>()? foo11h() => null;
void Function(num)? foo11i() => null;
void Function(int)? foo11j() => null;
void Function([num?])? foo11k() => null;
void Function([int?])? foo11l() => null;
void Function({num? a})? foo11m() => null;
void Function({int? a})? foo11n() => null;
void foo11o<U extends num, T extends void Function<R extends num>(U)>() {}
void foo11p<U extends int, T extends void Function<R extends int>(U)>() {}
void foo11q<S extends num, T extends void Function(S)>() {}
void foo11r<S extends int, T extends void Function(S)>() {}
void foo11s(num Function() a) {}
void foo11t(int Function() a) {}
void foo11u([num Function()? a]) {}
void foo11v([int Function()? a]) {}
void foo11w({num Function()? a}) {}
void foo11x({int Function()? a}) {}

// These should not work - they are changing part of the function signature

@TReflect(foo11a)
void Function<T>()? bar11a0() => null;

@TReflect(foo11a)
void Function(int a)? bar11a1() => null;

@TReflect(foo11a)
void Function([int? a])? bar11a2() => null;

@TReflect(foo11a)
void Function({int? a})? bar11a3() => null;

@TReflect(foo11b)
String Function()? bar11b1() => null;

@TReflect(foo11f)
void Function()? bar11f0() => null;

@TReflect(foo11f)
void Function<S, T>()? bar11f1() => null;

@TReflect(foo11i)
void Function(String)? bar11i0() => null;

@TReflect(foo11i)
void Function(num, String)? bar11i1() => null;

@TReflect(foo11k)
void Function([String?])? bar11k0() => null;

@TReflect(foo11k)
void Function([num?, String?])? bar11k1() => null;

@TReflect(foo11m)
void Function({String? a})? bar11m0() => null;

@TReflect(foo11m)
void Function({num? a, String? b})? bar11m1() => null;

// These should all work - they are always further specifying a type in the
// function return

@TReflect(foo11b)
int Function()? bar11b() => null;

@TReflect(foo11d)
Iterable<int> Function()? bar11d0() => null;

@TReflect(foo11d)
List<num> Function()? bar11d1() => null;

@TReflect(foo11d)
List<int> Function()? bar11d2() => null;

// These should not work - they are generalizing a type in the function return

@TReflect(foo11c)
num Function()? bar11c() => null;

@TReflect(foo11e)
List<num> Function()? bar11e() => null;

// These should all work - they are preserving the templated type

@TReflect(foo11f)
void Function<T>()? bar11f() => null;

@TReflect(foo11g)
void Function<T extends num>()? bar11g0() => null;

// These should not work - they are changing the templated type

@TReflect(foo11g)
void Function<T extends int>()? bar11g1() => null;

@TReflect(foo11h)
void Function<T extends num>()? bar11h() => null;

// These should all work - they are generalizing a type in the function argument

@TReflect(foo11j)
void Function(num)? bar11j() => null;

@TReflect(foo11l)
void Function([num?])? bar11l() => null;

@TReflect(foo11n)
void Function({num? a})? bar11n() => null;

// These should not work - they are specializing a type in the function argument

@TReflect(foo11i)
void Function(int)? bar11i() => null;

@TReflect(foo11k)
void Function([int?])? bar11k() => null;

@TReflect(foo11m)
void Function({int? a})? bar11m() => null;

// These should all work - they are preserving the templated type by keeping the
// arguments the same

@TReflect(foo11o)
void bar11o0<U extends num, T extends void Function<R extends num>(U)>() {}

@TReflect(foo11p)
void bar11p0<U extends int, T extends void Function<R extends int>(U)>() {}

@TReflect(foo11q)
void bar11q0<S extends num, T extends void Function(S)>() {}

// These should not work - they are breaking the templated type by either
// generalizing or specializing the arguments. The template rule superimposes
// itself over the argument specialization one

@TReflect(foo11o)
void bar11o1<U extends int, T extends void Function<R extends num>(U)>() {}

@TReflect(foo11o)
void bar11o2<U extends num, T extends void Function<R extends int>(U)>() {}

@TReflect(foo11p)
void bar11p1<U extends int, T extends void Function<R extends num>(U)>() {}

@TReflect(foo11q)
void bar11q1<S extends int, T extends void Function(S)>() {}

@TReflect(foo11r)
void bar11r<S extends num, T extends void Function(S)>() {}

// These should all work - they just apply previous examples to arguments

@TReflect(foo11s)
void bar11s(int Function() a) {}

@TReflect(foo11u)
void bar11u([int Function()? a]) {}

@TReflect(foo11w)
void bar11w({int Function()? a}) {}

// These should not work - for the same reason as previous examples

@TReflect(foo11t)
void bar11t(num Function() a) {}

@TReflect(foo11v)
void bar11v([num Function()? a]) {}

@TReflect(foo11x)
void bar11x({num Function()? a}) {}
