// Written in the D programming language.
/**
Simple set of (saner) traits.

For internal use only.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module wg.util.traits;

///
enum bool isFloatingPoint(T) = __traits(isFloating, T);
///
enum bool isSigned(T) = __traits(isArithmetic, T) && !__traits(isUnsigned, T);
///
enum bool isReferenceType(T) = is(T == class) || is(T == interface) || (is(T == U*, U) && is(U == struct));

///
template Unqual(T)
{
    import core.internal.traits : CoreUnqual = Unqual;
    alias Unqual = CoreUnqual!(T);
}
