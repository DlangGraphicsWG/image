module wg.color.rgb.format;

import wg.color.rgb.colorspace : RGBColorSpace;

struct RGBFormatDescriptor
{
    enum Component : ubyte
    {
        Red = 0,
        Green,
        Blue,
        Alpha,
        Luma,
        Exponent,
        ValueU,
        ValueV,
        ValueW,
        ValueQ,
        Unused
    }

    enum Format : ubyte
    {
        NormInt,
        SignedNormInt,
        FloatingPoint,
        FixedPoint,
        SignedFixedPoint,
        UnsignedInt,
        SignedInt,
        Mantissa,
        Exponent
    }

    struct ComponentDesc
    {
        Component type;
        Format format = Format.NormInt;
        ubyte bits = 8;
        ubyte fracBits = 0;
    }

    byte bits;
    byte alignment;
    bool bigEndian;
    bool hasSharedExponent;

    ushort componentsPresent;

    const(ComponentDesc)[] components;

    const(RGBColorSpace)* colorSpace;

    string userData;
}
