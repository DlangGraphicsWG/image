// Written in the D programming language.
/**
This module implements support for packed floats.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.util.packedfloat;

@safe pure nothrow @nogc:

/**
Implements a customisable packed float.

Params:
    $(D_INLINECODE I) = Underlying compressed data type.
    $(D_INLINECODE bits) = Total number of bits in the packed float.
    $(D_INLINECODE signed) = Whether the float is signed or unsigned.
    $(D_INLINECODE expBits) = Number of exponent bits. Mantissa is $(D_INLINECODE bits - expBits - (signed ? 1 : 0)) bits.
    $(D_INLINECODE bias) = Exponent bias. Default is $(D_INLINECODE 2^^(expBits-1) - 1).
*/
struct PackedFloat(I, size_t bits, bool signed, size_t expBits, int bias = (1 << expBits-1)-1)
{
    static assert (bits < 32, "Packed float is only for small floats");
    static assert (expBits < bits - signed, "Too many exponent bits");
    static assert (mant_dig <= 23, "Mantissas > 23 bits not supported");

    ///
    alias IntType = I;

    ///
    enum infinity = typeof(this)(exponentMask);
    ///
    enum nan = typeof(this)(exponentMask | mantissaMask);

    ///
    enum mant_dig = bits - expBits - signed;

    ///
    enum max = typeof(this)((exponentMask - 1) | mantissaMask);
    ///
    enum min_normal = typeof(this)(1 << mant_dig);

    alias asFloat this;

    ///
    this(IntType value)
    {
        packed = value;
    }
    ///
    this(float value)
    {
        asFloat(value);
    }

    ///
    @property float asFloat() const
    {
        union U {
            uint unpacked = 0;
            float f;
        }
        U u;
        static if (signed)
            u.unpacked = (packed & signMask) << (32 - bits);
        if (packed & (exponentMask | mantissaMask))
        {
            if ((packed & exponentMask) == exponentMask)
            {
                u.unpacked |= 0xFF << 23;
                if (packed & mantissaMask)
                    u.unpacked |= (packed & (1 << mant_dig - 1)) ? (1 << 23) - 1 : (1 << 22) - 1;
            }
            else if ((packed & exponentMask) == 0)
            {
                // TODO: we don't support denormals...
                //       clamp to zero
            }
            else
            {
                u.unpacked |= int(((packed & exponentMask) >> mant_dig) - bias + 127) << 23;
                u.unpacked |= (packed & mantissaMask) << (23 - mant_dig);
            }
        }
        return u.f;
    }
    ///
    @property void asFloat(float f)
    {
        union U {
            this(float f) { this.f = f; }
            float f;
            uint unpacked;
        }
        U u = U(f);
        packed = 0;
        static if (signed)
            packed = (u.unpacked >> (32 - bits)) & signMask;
        // check it's not zero
        if ((u.unpacked & 0x7FFFFFFF) != 0)
        {
            enum I maxExponent = (1 << expBits) - 1;
            int exp = int((u.unpacked >> 23) & 0xFF) - 127 + bias;
            if (exp >= maxExponent)
            {
                // large numbers clamp to infinity
                packed |= exponentMask;
                // or is it a NaN?
                if (exp == 128 + bias && (u.unpacked & ((1 << 23) - 1)) != 0)
                    packed |= (u.unpacked & (1 << 22)) ? mantissaMask : mantissaMask >> 1;
            }
            else if (exp <= 0)
            {
                // TODO: should support denormals?
                //       is it in the spec for small floats?
                //       we'll clamp to zero
            }
            else
            {
                if (signed || u.unpacked >> 31 == 0)
                {
                    packed |= exp << mant_dig;
                    packed |= (u.unpacked >> (23 - mant_dig)) & mantissaMask;
                }
            }
        }
    }

private:
    enum I exponentMask = ((1 << expBits) - 1) << mant_dig;
    enum I mantissaMask = (1 << mant_dig) - 1;
    enum I signMask = 1 << (bits - 1);

    I packed;
}
unittest
{
    PackedFloat!(ushort, 16, true, 5) f;
    f.asFloat = 1.0f;               assert(f.asFloat == 1.0f);
    f.asFloat = -1.0f;              assert(f.asFloat == -1.0f);
    f.asFloat = 10.5f;              assert(f.asFloat == 10.5f);
    f.asFloat = 0.0f;               assert(f.asFloat == 0.0f);
    f.asFloat = -0.0f;              assert(f.asFloat == -0.0f);
    f.asFloat = 0.0000001f;         assert(f.asFloat == 0.0f);
    f.asFloat = 1000000.0f;         assert(f.asFloat == float.infinity);
    f.asFloat = -1000000.0f;        assert(f.asFloat == -float.infinity);
    f.asFloat = float.infinity;     assert(f.asFloat == float.infinity);
    f.asFloat = -float.infinity;    assert(f.asFloat == -float.infinity);
//    f.asFloat = float.nan;          assert(f.asFloat is float.nan); // how to we test nan?

    PackedFloat!(ushort, 11, false, 5) f2;
    f2.asFloat = 1.0f;              assert(f2.asFloat == 1.0f);
    f2.asFloat = -1.0f;             assert(f2.asFloat == 0.0f);
    f2.asFloat = 10.5f;             assert(f2.asFloat == 10.5f);
    f2.asFloat = 0.0f;              assert(f2.asFloat == 0.0f);
    f2.asFloat = 0.0000001f;        assert(f2.asFloat == 0.0f);
    f2.asFloat = 1000000.0f;        assert(f2.asFloat is float.infinity);
    f2.asFloat = float.infinity;    assert(f2.asFloat is float.infinity);
//    f2.asFloat = float.nan;         assert(f2.asFloat is float.nan); // how to we test nan?

    PackedFloat!(ubyte, 8, false, 3) f3;
    f3.asFloat = 1.0f;              assert(f3.asFloat == 1.0f);
    f3.asFloat = -1.0f;             assert(f3.asFloat == 0.0f);
    f3.asFloat = 10.5f;             assert(f3.asFloat == 10.5f);
    f3.asFloat = 0.0f;              assert(f3.asFloat == 0.0f);
    f3.asFloat = 0.0000001f;        assert(f3.asFloat == 0.0f);
    f3.asFloat = 1000000.0f;        assert(f3.asFloat is float.infinity);
    f3.asFloat = float.infinity;    assert(f3.asFloat is float.infinity);
//    f3.asFloat = float.nan;         assert(f3.asFloat is float.nan); // how to we test nan?
}
