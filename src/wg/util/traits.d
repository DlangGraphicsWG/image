module wg.util.traits;

// traits
enum bool isFloatingPoint(T) = __traits(isFloating, T);

enum bool isSigned(T) = __traits(isArithmetic, T) && !__traits(isUnsigned, T);

enum bool isReferenceType(T) = is(T == class) || is(T == interface) || (is(T == U*, U) && is(U == struct));
