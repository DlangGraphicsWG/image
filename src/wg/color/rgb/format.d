module wg.color.rgb.format;

import wg.util.allocator;

/**
 * RGB format descriptor.
 */
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

        AnyFloating     = 1 << 10,
        AllFloating     = 1 << 11,
        AllSameFormat   = 1 << 12,
        AllSameSize     = 1 << 13,
        AllAligned      = 1 << 14,
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

    const(char)[] colorSpace;
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
    RGBFormatDescriptor.ComponentDesc[6] components = void;
    string error = format.parseRGBFormat(r, components);
    enforce(error == null, format ~ " : " ~ error);

    // dup components, colorSpace, and userData into gc buffers
    r.components = r.components.dup;
    if (r.colorSpace.isSubString(format))
        r.colorSpace = r.colorSpace.idup;
    if (r.userData)
        r.userData = r.userData.idup;

    return r;
}
///
unittest
{
    // simplest format
    RGBFormatDescriptor format = parseRGBFormat("rgb");
    assert(format.bits == 24);
    assert(format.alignment == 8);
    assert(format.components.length == 3);
    assert(format.components[0].bits == 8);
    assert(format.components[0].format == RGBFormatDescriptor.Format.NormInt);
    assert(!!(format.flags & RGBFormatDescriptor.Flags.AllSameSize) == true);
    assert(!!(format.flags & RGBFormatDescriptor.Flags.AllAligned) == true);
    assert(format.colorSpace[] == "sRGB");

    // complex format
    RGBFormatDescriptor format2 = parseRGBFormat("bgra_10_10_10_2_Rec.2020@D50^1.7_BE_#userdata");
    assert(format2.bits == 32);
    assert(format2.alignment == 32);
    assert(format2.components.length == 4);
    assert(format2.components[0].type == RGBFormatDescriptor.Component.Blue);
    assert(format2.components[1].type == RGBFormatDescriptor.Component.Green);
    assert(format2.components[2].type == RGBFormatDescriptor.Component.Red);
    assert(format2.components[3].type == RGBFormatDescriptor.Component.Alpha);
    assert(format2.components[0].bits == 10);
    assert(format2.components[1].bits == 10);
    assert(format2.components[2].bits == 10);
    assert(format2.components[3].bits == 2);
    assert(format2.colorSpace[] == "Rec.2020@D50^1.7");
    assert(!!(format2.flags & RGBFormatDescriptor.Flags.BigEndian) == true);
    assert(format2.userData[] == "userdata");

    // prove CTFE works
    static immutable RGBFormatDescriptor format3 = parseRGBFormat("ra_f16_s8.8_AdobeRGB");
    static assert(format3.bits == 32);
    static assert(format3.alignment == 16);
    static assert(format3.components.length == 2);
    static assert(format3.components[0].type == RGBFormatDescriptor.Component.Red);
    static assert(format3.components[1].type == RGBFormatDescriptor.Component.Alpha);
    static assert(format3.components[0].format == RGBFormatDescriptor.Format.FloatingPoint);
    static assert(format3.components[1].format == RGBFormatDescriptor.Format.SignedFixedPoint);
    static assert(format3.components[0].bits == 16);
    static assert(format3.components[1].bits == 16 && format3.components[1].fracBits == 8);
    static assert(format3.colorSpace[] == "AdobeRGB");
}

/**
 * Parse RGB format descriptor from string.
 */
RGBFormatDescriptor* parseRGBFormat(const(char)[] format, Allocator* allocator) @trusted nothrow @nogc
{
    // parse data into stack buffers
    RGBFormatDescriptor r;
    RGBFormatDescriptor.ComponentDesc[6] components = void;
    string error = format.parseRGBFormat(r, components);
    if (error)
        return null;

    bool csNeedsAllocation = r.colorSpace.isSubString(format);

    // allocate a buffer sufficient for all the data
    size_t bufferSize = RGBFormatDescriptor.sizeof +
                        RGBFormatDescriptor.ComponentDesc.sizeof*r.components.length +
                        (csNeedsAllocation ? r.colorSpace.length : 0) +
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
    if (csNeedsAllocation)
    {
        char[] cs = (cast(char*)userData)[0 .. r.colorSpace.length];
        userData += r.colorSpace.length;
        cs[] = r.colorSpace[];
        fmt.colorSpace = cs;
    }

    // copy userData
    if (r.userData.length)
    {
        userData[0 .. r.userData.length] = r.userData[];
        fmt.userData = userData[0 .. r.userData.length];
    }

    return fmt;
}
///
unittest
{
    import wg.util.allocator;
    Allocator gcAlloc = getGcAllocator();

    RGBFormatDescriptor* format = parseRGBFormat("bgra_10_10_10_2_Rec.2020@D50^1.7_BE_#userdata", &gcAlloc);
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
    assert(format.colorSpace[] == "Rec.2020@D50^1.7");
    assert(!!(format.flags & RGBFormatDescriptor.Flags.BigEndian) == true);
    assert(format.userData[] == "userdata");
}

/**
 * Make format string from RGB format descriptor.
 */
string makeFormatString(const(RGBFormatDescriptor) desc) @safe pure nothrow
{
    import wg.util.format : formatInt;

    alias Component = RGBFormatDescriptor.Component;
    alias Format = RGBFormatDescriptor.Format;

    string format;
    bool needsElementFormat = false;

    foreach (ref e; desc.components)
    {
        if (e.format != Format.NormInt || e.bits != 8)
            needsElementFormat = true;
        final switch (e.type)
        {
            case Component.Red:     format ~= 'r'; break;
            case Component.Green:   format ~= 'g'; break;
            case Component.Blue:    format ~= 'b'; break;
            case Component.Alpha:   format ~= 'a'; break;
            case Component.Luma:    format ~= 'l'; break;
            case Component.Exponent:format ~= 'e'; break;
            case Component.Unused:  format ~= 'x'; break;
        }
    }

    if (needsElementFormat)
    {
        foreach (ref e; desc.components)
        {
            switch (e.format)
            {
                case Format.SignedNormInt:
                case Format.SignedFixedPoint:   format ~= "_s"; break;
                case Format.FloatingPoint:      format ~= "_f"; break;
                case Format.UnsignedInt:        format ~= "_u"; break;
                case Format.SignedInt:          format ~= "_i"; break;
                default:                        format ~= '_';  break;
            }
            format ~= formatInt!int(e.bits - e.fracBits);
            if (e.fracBits)
                format ~= '.' ~ formatInt!int(e.fracBits);
        }
    }

    if (desc.colorSpace[] != "sRGB")
        format ~= '_' ~ desc.colorSpace;

    if (desc.flags & RGBFormatDescriptor.Flags.BigEndian)
        format ~= "_BE";

    if (desc.userData)
        format ~= "_#" ~ desc.userData;

    return format;
}

/**
* Canonicalise RGB format string.
*/
string canonicalFormat(const(char)[] format) @trusted pure
{
    import std.exception : enforce;

    RGBFormatDescriptor fmt;
    RGBFormatDescriptor.ComponentDesc[6] components = void;
    string error = format.parseRGBFormat(fmt, components);
    enforce(error == null,"Invalid RGB format descriptor: " ~ format);
    // TODO: accept an output buffer...
    return makeFormatString(fmt);
}
///
unittest
{
    static assert(canonicalFormat("rgb") == "rgb");
    static assert(canonicalFormat("rgb_8_8_8") == "rgb");
    static assert(canonicalFormat("rgb_sRGB") == "rgb");
    static assert(canonicalFormat("rgb_8_8_8_sRGB") == "rgb");
//    static assert(canonicalFormat("rgb_8_8_8_sRGB@D65") == "rgb");  // TODO: simplify colour spaces
//    static assert(canonicalFormat("rgb_8_8_8_sRGB^sRGB") == "rgb"); // TODO: simplify colour spaces
    static assert(canonicalFormat("rgb_8_8_8_sRGB@D50") == "rgb_sRGB@D50");
    static assert(canonicalFormat("rgb_8_8_8_sRGB_BE_#data") == "rgb_BE_#data");
    static assert(canonicalFormat("rgba_10_10_10_2_sRGB@D50") == "rgba_10_10_10_2_sRGB@D50");
}


package:

string parseRGBFormat(const(char)[] str, out RGBFormatDescriptor format, ref RGBFormatDescriptor.ComponentDesc[6] components) @trusted pure nothrow @nogc
{
    import wg.color.rgb.colorspace : RGBColorSpace, findRGBColorspace, parseRGBColorSpace;

    alias Component = RGBFormatDescriptor.Component;
    alias Format = RGBFormatDescriptor.Format;
    alias Flags = RGBFormatDescriptor.Flags;

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
    static immutable ubyte[26] componentMap = [
        Component.Alpha, Component.Blue, 0xFF, 0xFF, Component.Exponent, 0xFF,                // A - F
        Component.Green, 0xFF, 0xFF, 0xFF, 0xFF, Component.Luma, 0xFF, 0xFF, 0xFF,            // G - O
        0xFF, 0xFF, Component.Red, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, Component.Unused, 0xFF, 0xFF // P - Z
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
        Component type = cast(Component)componentMap[c - 'a'];
        if ((format.flags & (1 << type)) != 0)
            return "Duplicate component types not allowed";
        format.flags |= 1 << type;
        components[numComponents++] = RGBFormatDescriptor.ComponentDesc(type);
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
            assert(false);
//            continue;
        }

        // 'BE'
        if (tail == "BE")
        {
            format.flags |= Flags.BigEndian;
            continue;
        }

        // color space
        immutable(RGBColorSpace)* standardCs = findRGBColorspace(tail);
        if (standardCs)
        {
            format.colorSpace = standardCs.id;
            continue;
        }
        // maybe custom color space...
        // TODO: just validate it, no need to return output
        RGBColorSpace cs = void;
        size_t taken = tail.parseRGBColorSpace(cs);
        if (taken)
        {
            if (taken != tail.length)
                return "Invalid color space";
            format.colorSpace = tail;
            continue;
        }

        // the tail wasn't anything we know about...
        // it's probably part of the format data; we'll put it back on the format string.
        str = str.ptr[0 .. str.length + tail.length + 1]; // one for the underscore
        break;
    }

    // if no color space was specified, assume sRGB
    if (!format.colorSpace)
        format.colorSpace = "sRGB";

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
                case 's': components[i].format = Format.SignedNormInt;  goto skipTwo;
                case 'f': components[i].format = Format.FloatingPoint;  goto skipTwo;
                case 'u': components[i].format = Format.UnsignedInt;    goto skipTwo;
                case 'i': components[i].format = Format.SignedInt;      goto skipTwo;
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
                if (components[i].format == Format.NormInt)
                    components[i].format = Format.FixedPoint;
                else if (components[i].format == Format.SignedNormInt)
                    components[i].format = Format.SignedFixedPoint;
                else if (components[i].format != Format.FloatingPoint)
                    return "Fractional components may only be unsigned, signed, or floating point (ie, `4.4`, `s4.4` or `f3.7`)";

                // parse the fractional size
                taken = str[1 .. $].parseInt(components[i].fracBits);
                if (!taken)
                    return "Invalid component descriptor";
                if (components[i].fracBits == 0)
                    return "Invalid fractional bits: 0";
                components[i].bits += components[i].fracBits;
                str = str[1 + taken .. $]; // include the '.'
            }

            // if it has a shared exponent, then assert the rules
            if ((format.flags & (1 << Component.Exponent)) != 0)
            {
                if (components[i].format != Format.NormInt)
                    return "Shared exponent formats may not have qualified component types";
                components[i].format = components[i].type == Component.Exponent ? Format.Exponent : Format.Mantissa;
            }
        }
        if (str.length)
            return "Invalid RGB format string";
    }

    // prep the detail data...
    bool allAligned = true;
    ubyte sameSize = components[0].bits;
    bool sameFormat = true;
    uint numFloating = 0;
    foreach (ref c; components[0 .. numComponents])
    {
        format.bits += c.bits;
        allAligned = allAligned && isAlignedType(c.bits);
        sameSize = c.bits == sameSize ? sameSize : 0;
        sameFormat = sameFormat && c.format == components[0].format;
        numFloating += c.format == Format.FloatingPoint ? 1 : 0;
    }
    if ((format.flags & (1 << Component.Exponent)) != 0)
    {
        format.alignment = format.bits;
        format.flags |= Flags.AnyFloating | Flags.AllFloating;
    }
    else
    {
        format.alignment = allAligned && sameSize != 0 ? sameSize : format.bits;
        if (numFloating == numComponents)
            format.flags |= Flags.AnyFloating | Flags.AllFloating;
        else if (numFloating > 0)
            format.flags |= Flags.AnyFloating;

    }
    if (allAligned)
        format.flags |= Flags.AllAligned;
    if (sameSize != 0)
        format.flags |= Flags.AllSameSize;
    if (sameFormat)
        format.flags |= Flags.AllSameFormat;
    if ((format.flags & (1 << Component.Luma)) != 0 && (format.flags & 0x7) != 0)
        return "RGB colors may not have both 'r/g/b' and 'l' channels";

    format.components = components[0 .. numComponents];

    return null;
}

// TODO: move to util?
bool isAlignedType(I)(I x)
{
    return x >= 8 && (x & (x - 1)) == 0;
}

bool isSubString(const(char)[] subStr, const(char)[] str) pure nothrow @nogc
{
    return &str[0] <= &subStr[0] && &str[$-1] >= &subStr[$-1];
}
