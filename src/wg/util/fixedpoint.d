// Written in the D programming language.
/**
This module implements support for fixed point numbers.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.util.fixedpoint;

@safe pure nothrow @nogc:

/**
Implements a fixed point number.

Params:
$(D_INLINECODE I) = Underlying integer data type.
$(D_INLINECODE frac) = Number of fractional bits.
*/
struct FixedPoint(I, int frac)
{
    ///
    alias IntType = I;

    ///
    enum max = I.max / float(1 << frac);
    ///
    enum min_normal = 1 / float(1 << frac);

    alias asFloat this;

    ///
    float asFloat() const pure nothrow @nogc @safe
    {
        return val / float(1 << frac);
    }
    ///
    void asFloat(float f) pure nothrow @nogc @safe
    {
        val = cast(I)(f * (1 << frac));
    }

    private I val;
}
