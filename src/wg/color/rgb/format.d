module wg.color.rgb.format;

import wg.color.rgb.colorspace : RGBColorSpace, findRGBColorspace;
import wg.util.allocator;

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

    enum Flags : ushort
    {
        ComponentPresentMask = 0x7FF,

        AllSameSize     = 1 << 13,
        AllByteAligned  = 1 << 14,
        BigEndian       = 1 << 15
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
    ushort flags;

    ComponentDesc[] components;

    const(RGBColorSpace)* colorSpace;

    const(char)[] userData;
}

/**
 * Parse RGB format descriptor from string.
 */
RGBFormatDescriptor parseRGBFormat(const(char)[] format) @trusted pure
{
    import std.exception : enforce;

    RGBFormatDescriptor r;

    // parse data into stack buffers
    RGBFormatDescriptor.ComponentDesc[32] components = void;
    RGBColorSpace cs = void;
    string error = format.parseRGBFormat(r, components, cs);
    enforce(error == null, format ~ " : " ~ error);

    // dup components, colorSpace, and userData into gc buffers
    r.components = r.components.dup;
    if (r.colorSpace == &cs)
    {
        auto copy = new RGBColorSpace;
//        *copy = cs; // TODO: can't evaluate in ctfe? wat?
        (*copy).tupleof = cs.tupleof; // HACK
        r.colorSpace = copy;
    }
    if (r.userData)
        r.userData = r.userData.idup;

    return r;
}
///
unittest
{
    import wg.color.standard_illuminant;

    RGBFormatDescriptor format = parseRGBFormat("bgra_10_10_10_2_Rec.2020@D50^2.2_BE_#userdata");
    assert(format.bits == 32);
    assert(format.alignment == 32);
    assert(format.components.length == 4);
    assert(format.components[0].type == RGBFormatDescriptor.Component.Blue);
    assert(format.components[1].type == RGBFormatDescriptor.Component.Green);
    assert(format.components[2].type == RGBFormatDescriptor.Component.Red);
    assert(format.components[3].type == RGBFormatDescriptor.Component.Alpha);
    assert(format.components[0].bits == 10);
    assert(format.components[1].bits == 10);
    assert(format.components[2].bits == 10);
    assert(format.components[3].bits == 2);
    assert(format.colorSpace.id[] == "Rec.2020");
    assert(format.colorSpace.white == StandardIlluminant.D50);
    assert(format.colorSpace.gamma.name[] == "2.2");
    assert(!!(format.flags & RGBFormatDescriptor.Flags.BigEndian) == true);
    assert(format.userData[] == "userdata");

    // prove CTFE works
    static immutable RGBFormatDescriptor format2 = parseRGBFormat("ra_f16_s8.8");
    static assert(format2.bits == 32);
    static assert(format2.alignment == 16);
    static assert(format2.components.length == 2);
    static assert(format2.components[0].type == RGBFormatDescriptor.Component.Red);
    static assert(format2.components[1].type == RGBFormatDescriptor.Component.Alpha);
    static assert(format2.components[0].format == RGBFormatDescriptor.Format.FloatingPoint);
    static assert(format2.components[1].format == RGBFormatDescriptor.Format.SignedFixedPoint);
    static assert(format2.components[0].bits == 16);
    static assert(format2.components[1].bits == 16 && format2.components[1].fracBits == 8);
    static assert(format2.colorSpace.id[] == "sRGB");

    // simplest format
    static immutable RGBFormatDescriptor format3 = parseRGBFormat("rgb");
    static assert(format3.bits == 24);
    static assert(format3.alignment == 8);
    static assert(format3.components.length == 3);
    static assert(format3.components[0].bits == 8);
    static assert(format3.components[0].format == RGBFormatDescriptor.Format.NormInt);
    static assert(!!(format3.flags & RGBFormatDescriptor.Flags.AllSameSize) == true);
    static assert(!!(format3.flags & RGBFormatDescriptor.Flags.AllByteAligned) == true);
    assert(format.colorSpace.id[] == "sRGB");
}

/**
 * Parse RGB format descriptor from string.
 */
RGBFormatDescriptor* parseRGBFormat(const(char)[] format, Allocator* allocator) @trusted nothrow @nogc
{
    // parse data into stack buffers
    RGBFormatDescriptor r;
    RGBFormatDescriptor.ComponentDesc[32] components = void;
    RGBColorSpace cs;
    string error = format.parseRGBFormat(r, components, cs);
    if (error)
        return null;

    // allocate a buffer sufficient for all the data
    size_t bufferSize = RGBFormatDescriptor.sizeof +
                        RGBFormatDescriptor.ComponentDesc.sizeof*r.components.length +
                        (r.colorSpace == &cs ? RGBColorSpace.sizeof : 0) +
                        r.userData.length;
    void[] buffer = allocator.allocate(bufferSize);

    // copy header
    RGBFormatDescriptor* fmt = cast(RGBFormatDescriptor*)buffer.ptr;
    *fmt = r;

    // copy component data
    fmt.components = (cast(RGBFormatDescriptor.ComponentDesc*)&fmt[1])[0 .. r.components.length];
    fmt.components[] = r.components[];

    char* userData = cast(char*)&fmt.components.ptr[fmt.components.length];

    // copy the color space if it's not a standard
    if (r.colorSpace == &cs)
    {
        RGBColorSpace* newCs = cast(RGBColorSpace*)userData;
        userData += RGBColorSpace.sizeof;
        *newCs = *r.colorSpace;
        fmt.colorSpace = newCs;
    }

    // copy userData
    if (r.userData.length)
    {
        userData[0 .. r.userData.length] = r.userData[];
        fmt.userData = userData[0 .. r.userData.length];
    }

    return fmt;
}


private:

string parseRGBFormat(const(char)[] str, out RGBFormatDescriptor format, ref RGBFormatDescriptor.ComponentDesc[32] components, ref RGBColorSpace cs) @trusted pure nothrow @nogc
{
    import wg.color.rgb.parse : parseRGBColorSpace;

    // TODO: move this to util?
    static const(char)[] popBackToken(ref const(char)[] format, char delim)
    {
        size_t i = format.length;
        while (i > 0) if (format[--i] == delim)
        {
            const(char)[] r = format[i + 1 .. $];
            format = format[0 .. i];
            return r;
        }
        return null;
    }

    // look-up table for color components
    alias Component = RGBFormatDescriptor.Component;
    static immutable ubyte[26] componentMap = [
        Component.Alpha, Component.Blue, 0xFF, 0xFF, Component.Exponent, 0xFF, Component.Green, 0xFF,    // A - H
        0xFF, 0xFF, 0xFF, Component.Luma, 0xFF, 0xFF, 0xFF, 0xFF, Component.ValueQ, Component.Red, 0xFF, // I - S
        0xFF, Component.ValueU, Component.ValueV, Component.ValueW, Component.Unused, 0xFF, 0xFF         // T - Z
    ];

    // parse components
    size_t numComponents = 0;
    while (str.length && str[0] != '_')
    {
        char c = str[0];
        if (numComponents == components.length)
            return "Too many components in RGB color format";
        if (c < 'a' || c > 'z' || componentMap[c - 'a'] == 0xFF)
            return "Not an RGB color format";
        components[numComponents++] = RGBFormatDescriptor.ComponentDesc(cast(Component)componentMap[c - 'a']);
        str = str[1 .. $];
    }
    if (numComponents == 0)
        return "Not an RGB color format";

    // since the format section is hard to parse, we'll do it last...
    // feed from the tail of the string
    const(char)[] tail;
    while ((tail = popBackToken(str, '_')).length != 0)
    {
        // swizzle data
        if (tail[0] == '#')
        {
            format.userData = tail[1 .. $];
            continue;
        }

        // swizzle data
        if (tail[0] == 'Z')
        {
            // parse swizzle...
//            assert(false);
            continue;
        }

        // 'BE'
        if (tail == "BE")
        {
            format.flags |= RGBFormatDescriptor.Flags.BigEndian;
            continue;
        }

        // color space
        // TODO: work out CTFE problem...
//        immutable(RGBColorSpace)* standardCs = findRGBColorspace(tail);
//        if (standardCs)
//        {
//            format.colorSpace = standardCs;
//            continue;
//        }
        size_t taken = tail.parseRGBColorSpace(cs);
        if (taken)
        {
            format.colorSpace = &cs;
            continue;
        }

        // the tail wasn't anything we know about...
        // it's probably part of the format data; we'll put it back on the format string.
        str = str.ptr[0 .. str.length + tail.length + 1]; // one for the underscore
        break;
    }

    // if no color space was specified, assume sRGB
    if (!format.colorSpace)
    {
        // TODO: work out CTFE problem...
//        format.colorSpace = findRGBColorspace("sRGB");
        cs = *findRGBColorspace("sRGB");
        format.colorSpace = &cs;
    }

    // parse format data...
    if (str.length > 0)
    {
        import wg.util.parse : parseInt;

        // TODO: handle block-compression formats...

        // no block compression
        for (size_t i = 0; i < numComponents; ++i)
        {
            if (str.length < 2 || str[0] != '_')
                return "Invalid format string";

            // check if the type is qualified
            switch (str[1])
            {
                case 's': components[i].format = RGBFormatDescriptor.Format.SignedNormInt;  goto skipTwo;
                case 'f': components[i].format = RGBFormatDescriptor.Format.FloatingPoint;  goto skipTwo;
                case 'u': components[i].format = RGBFormatDescriptor.Format.UnsignedInt;    goto skipTwo;
                case 'i': components[i].format = RGBFormatDescriptor.Format.SignedInt;      goto skipTwo;
                skipTwo: str = str[2 .. $]; break;
                default: str = str[1 .. $]; break;
            }

            // parse the component size
            size_t taken = str.parseInt(components[i].bits);
            if (!taken)
                return "Invalid component descriptor";
            if (components[i].bits == 0)
                return "Invalid component size: 0";
            str = str[taken .. $];

            // if it's fixed point
            if (str.length && str[0] == '.')
            {
                // validate the format
                if (components[i].format == RGBFormatDescriptor.Format.NormInt)
                    components[i].format = RGBFormatDescriptor.Format.FixedPoint;
                else if (components[i].format == RGBFormatDescriptor.Format.SignedNormInt)
                    components[i].format = RGBFormatDescriptor.Format.SignedFixedPoint;
                else
                    return "Fixed point components may only be unsigned or signed (ie, `4.4` or `s4.4`)";

                // parse the fractional size
                taken = str[1 .. $].parseInt(components[i].fracBits);
                if (!taken)
                    return "Invalid component descriptor";
                if (components[i].fracBits == 0)
                    return "Invalid fractional bits: 0";
                components[i].bits += components[i].fracBits;
                str = str[1 + taken .. $]; // include the '.'
            }
        }
        if (str.length)
            return "Invalid RGB format string";
    }

    // prep the detail data...
    bool allByteAligned = true;
    ubyte sameSize = components[0].bits;
    foreach (ref c; components[0 .. numComponents])
    {
        format.flags |= 1 << c.type;
        format.bits += c.bits;
        allByteAligned = allByteAligned && (c.bits & 7) == 0;
        sameSize = c.bits == sameSize ? sameSize : 0;
    }
    format.alignment = allByteAligned && sameSize != 0 && (format.flags & (1 << Component.Exponent)) == 0 ? sameSize : format.bits;
    if (allByteAligned)
        format.flags |= RGBFormatDescriptor.Flags.AllByteAligned;
    if (sameSize != 0)
        format.flags |= RGBFormatDescriptor.Flags.AllSameSize;

    format.components = components[0 .. numComponents];

    return null;
}
