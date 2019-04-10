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

///
template IntForSize(size_t bits, bool signed)
{
    static if (bits <= 8)
    {
        static if (signed)
            alias IntForSize = byte;
        else
            alias IntForSize = ubyte;
    }
    else static if (bits <= 16)
    {
        static if (signed)
            alias IntForSize = short;
        else
            alias IntForSize = ushort;
    }
    else static if (bits <= 32)
    {
        static if (signed)
            alias IntForSize = int;
        else
            alias IntForSize = uint;
    }
    else static if (bits <= 64)
    {
        static if (signed)
            alias IntForSize = long;
        else
            alias IntForSize = ulong;
    }
    else
        static assert("Invalid size!");
}
