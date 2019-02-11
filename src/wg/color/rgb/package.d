module wg.color.rgb;

public import wg.color.rgb.colorspace;
public import wg.color.rgb.format;

import wg.util.traits : isFloatingPoint;
import wg.util.normint;

import std.typecons : tuple;
import std.meta : AliasSeq;

/**
 * RGB colour type.
 */
struct RGB(string format)
{
    // make the format data available
    enum Format = parseRGBFormat(format);
    enum ColorSpace = parseRGBColorSpace(Format.colorSpace);

    enum isOperable = (Format.flags & RGBFormatDescriptor.Flags.AllSameFormat) &&
                      (Format.flags & RGBFormatDescriptor.Flags.AllAligned) &&
                      (Format.flags & RGBFormatDescriptor.Flags.AllSameSize);

    static if (isOperable)
    {
        // format can have hard members
        alias ComponentType = TypeFor!(Format.components[0].format, Format.components[0].bits, Format.components[0].fracBits);

        enum hasComponent(char c) = mixin("is(typeof(" ~ c ~ "))");

        // the argument type used for construction and methods
        static if (isFloatingPoint!ComponentType)
            alias ArgType = ComponentType;
        else
            alias ArgType = ComponentType.IntType;

        // mixin the color component struct members
        static foreach (c; Format.components)
            mixin(ComponentType.stringof ~ " " ~ ComponentName[c.type] ~ ';');

        /** Construct a color from RGB and optional alpha values. */
        this(ArgType r, ArgType g, ArgType b, ArgType a = 0)
        {
            foreach (c; AliasSeq!('r','g','b','a'))
                mixin(componentExpression("this._ = ComponentType(_);", c));
            static if (hasComponent!'l')
                this.l = cast(ComponentType)toMonochrome!ColorSpace(cast(float)ComponentType(r), cast(float)ComponentType(g), cast(float)ComponentType(b));
        }

        /** Construct a color from a luminance and optional alpha value. */
        this(ArgType l, ArgType a = 0)
        {
            foreach (c; AliasSeq!('l','r','g','b'))
                mixin(componentExpression("this._ = ComponentType(l);", c));
            static if (hasComponent!'a')
                this.a = ComponentType(a);
        }
    }
    else
    {
        // format needs bit-unpacking; components are properties
        pragma(msg, "TODO: fabricate properties for the bitpacked members...");
    }

    /** Return the RGB tristimulus values as a tuple.
    These will always be ordered (R, G, B).
    Any color channels not present will be 0. */
    @property auto tristimulus() const
    {
        static if (hasComponent!'l')
            return tuple(l, l, l);
        else
        {
            static if (!hasComponent!'r')
                enum r = ComponentType(0);
            static if (!hasComponent!'g')
                enum g = ComponentType(0);
            static if (!hasComponent!'b')
                enum b = ComponentType(0);
            return tuple(r, g, b);
        }
    }
    ///
    unittest
    {
        // tristimulus returns tuple of R, G, B
        static assert(RGB!"bgr"(255, 128, 10).tristimulus == tuple(NormalizedInt!ubyte(255), NormalizedInt!ubyte(128), NormalizedInt!ubyte(10)));
    }

    /** Return the RGB tristimulus values + alpha as a tuple.
    These will always be ordered (R, G, B, A). */
    @property auto tristimulusWithAlpha() const
    {
        static if (!hasComponent!'a')
            enum a = ComponentType(0);
        return tuple(tristimulus.expand, a);
    }
    ///
    unittest
    {
        // tristimulusWithAlpha returns tuple of R, G, B, A
        static assert(RGB!"bgra"(255, 128, 10, 80).tristimulusWithAlpha == tuple(NormalizedInt!ubyte(255), NormalizedInt!ubyte(128), NormalizedInt!ubyte(10), NormalizedInt!ubyte(80)));
    }
}
///
unittest
{
    RGB!"rgba" pixel;

    static assert(is(typeof(pixel.r) == NormalizedInt!ubyte));
    static assert(is(typeof(pixel.g) == NormalizedInt!ubyte));
    static assert(is(typeof(pixel.b) == NormalizedInt!ubyte));
    static assert(is(typeof(pixel.a) == NormalizedInt!ubyte));

    RGB!"la_f32_f32" pixel2;

    static assert(is(typeof(pixel2.l) == float));
    static assert(is(typeof(pixel2.a) == float));
}


private:

enum char[] ComponentName = [ 'r', 'g', 'b', 'a', 'l', 'e', 'x' ];

template TypeFor(RGBFormatDescriptor.Format format, size_t bits, size_t frac)
{
    static if (format == RGBFormatDescriptor.Format.NormInt || format == RGBFormatDescriptor.Format.SignedNormInt)
        alias TypeFor = NormalizedInt!(IntForSize!(bits, format == RGBFormatDescriptor.Format.SignedNormInt));
    else static if (format == RGBFormatDescriptor.Format.FloatingPoint)
        alias TypeFor = FloatForSize!bits;
    else static if (format == RGBFormatDescriptor.Format.UnsignedInt || format == RGBFormatDescriptor.Format.SignedInt)
        alias TypeFor = IntForSize!(bits, format == RGBFormatDescriptor.Format.SignedInt);
    else static if (format == RGBFormatDescriptor.Format.FixedPoint || format == RGBFormatDescriptor.Format.SignedFixedPoint)
        alias TypeFor = FixedPoint!(IntForSize!(bits, format == RGBFormatDescriptor.Format.SignedFixedPoint), frac);
    else static if (format == RGBFormatDescriptor.Format.Exponent || format == RGBFormatDescriptor.Format.Mantissa)
        alias TypeFor = IntForSize!(bits, false);
    else
        static assert("Invalid format and bits!");
}

template IntForSize(size_t size, bool signed)
{
    static if (size == 8)
    {
        static if (signed)
            alias IntForSize = byte;
        else
            alias IntForSize = ubyte;
    }
    else static if (size == 16)
    {
        static if (signed)
            alias IntForSize = short;
        else
            alias IntForSize = ushort;
    }
    else static if (size == 32)
    {
        static if (signed)
            alias IntForSize = int;
        else
            alias IntForSize = uint;
    }
    else static if (size == 64)
    {
        static if (signed)
            alias IntForSize = long;
        else
            alias IntForSize = ulong;
    }
    else
        static assert("Invalid size!");
}

template FloatForSize(size_t size)
{
    static if (size == 16)
        alias FloatForSize = float16;
    else static if (size == 32)
        alias FloatForSize = float;
    else static if (size == 64)
        alias FloatForSize = double;
    else
        static assert("Invalid size!");
}

// TODO: need a fixed point type
struct FixedPoint(I, int frac)
{
    alias IntType = I;

    alias asFloat this;

    float asFloat() const { assert(false); }
    void asFloat(float f) { assert(false); }

    private I val;
}

// TODO: need a float16 type
struct float16
{
    alias asFloat this;

    float asFloat() const { assert(false); }
    void asFloat(float f) { assert(false); }

    private ushort f;
}

// build mixin code to perform expresions per-element
string componentExpression(string expression, char component, string op = null)
{
    char[256] buffer;
    size_t o = 0;
    foreach (i; 0 .. expression.length)
    {
        if (expression[i] == '_')
            buffer[o++] = component;
        else if (expression[i] == '#')
        {
            buffer[o .. o + op.length] = op[];
            o += op.length;
        }
        else
            buffer[o++] = expression[i];
    }
    return "static if (hasComponent!'" ~ component ~ "')\n\t" ~ buffer[0 .. o].idup;
}
