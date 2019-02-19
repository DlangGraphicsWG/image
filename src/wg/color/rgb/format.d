// Written in the D programming language.
/**
RGB colorspaces format descriptor.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module wg.color.rgb.format;
import wg.util.allocator;

/**
RGB format descriptor.
*/
struct RGBFormatDescriptor
{
    ///
    enum Component : ubyte
    {
        ///
        Red = 0,
        ///
        Green,
        ///
        Blue,
        ///
        Alpha,
        ///
        Luma,
        ///
        Exponent,
        ///
        Unused
    }

    ///
    enum Format : ubyte
    {
        ///
        NormInt,
        ///
        SignedNormInt,
        ///
        FloatingPoint,
        ///
        FixedPoint,
        ///
        SignedFixedPoint,
        ///
        UnsignedInt,
        ///
        SignedInt,
        ///
        Exponent,
        ///
        Mantissa
    }

    ///
    enum Flags : ushort
    {
        ///
        AnyFloating     = 1 << 0,
        ///
        AllFloating     = 1 << 1,
        ///
        AllSameFormat   = 1 << 2,
        ///
        AllSameSize     = 1 << 3,
        ///
        AllAligned      = 1 << 4,
        ///
        BigEndian       = 1 << 5
    }

    ///
    struct ComponentDesc
    {
        ///
        Component type;
        ///
        Format format = Format.NormInt;
        ///
        ubyte offset = 0;
        ///
        ubyte bits = 0;
        ///
        ubyte fracBits = 0;
        ///
        byte expBias = 0;
    }

    ///
    ubyte bits;
    ///
    ubyte alignment;
    ///
    ubyte numComponents;
    ///
    ubyte flags;

    byte[6] componentIndex;
    ComponentDesc[5] componentData;

    ///
    const(char)[] colorSpace;
    ///
    const(char)[] userData;

    ///
    inout(ComponentDesc)[] components() return inout pure nothrow @nogc @safe { return componentData[0 .. numComponents]; }
    ///
    bool has(Component c) const pure nothrow @nogc @safe { return componentIndex[c] >= 0; }
}

/**
Parse RGB format descriptor from string.
*/
RGBFormatDescriptor parseRGBFormat(const(char)[] format) @trusted pure
{
    import std.exception : enforce;

    RGBFormatDescriptor r;

    // parse data into stack buffers
    string error = format.parseRGBFormat(r);
    enforce(error == null, format ~ " : " ~ error);

    // dup components, colorSpace, and userData into gc buffers
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
Parse RGB format descriptor from string.
*/
RGBFormatDescriptor* parseRGBFormat(const(char)[] format, Allocator* allocator) @trusted nothrow @nogc
{
    // parse data into stack buffers
    RGBFormatDescriptor r;
    string error = format.parseRGBFormat(r);
    if (error)
        return null;

    bool csNeedsAllocation = r.colorSpace.isSubString(format);

    // allocate a buffer sufficient for all the data
    size_t bufferSize = RGBFormatDescriptor.sizeof +
                        (csNeedsAllocation ? r.colorSpace.length : 0) +
                        r.userData.length;
    void[] buffer = allocator.allocate(bufferSize);

    // copy header
    RGBFormatDescriptor* fmt = cast(RGBFormatDescriptor*)buffer.ptr;
    *fmt = r;

    char* userData = cast(char*)&fmt[1];

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
    Allocator* gcAlloc = getGcAllocator();

    RGBFormatDescriptor* format = parseRGBFormat("bgra_10_10_10_2_Rec.2020@D50^1.7_BE_#userdata", gcAlloc);
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
Make format string from RGB format descriptor.
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
Canonicalise RGB format string.
*/
string canonicalFormat(const(char)[] format) @trusted pure
{
    import std.exception : enforce;

    RGBFormatDescriptor fmt;
    string error = format.parseRGBFormat(fmt);
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

string parseRGBFormat(const(char)[] str, out RGBFormatDescriptor format) @trusted pure nothrow @nogc
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
    size_t numElements = 0;
    Component[8] elementTypes;
    bool hasSharedExponent = false;
    while (str.length && str[0] != '_')
    {
        char c = str[0];
        if (numElements == elementTypes.length)
            return "Too many components in RGB color format";
        if (c < 'a' || c > 'z' || componentMap[c - 'a'] == 0xFF)
            return "Not an RGB color format";
        Component type = cast(Component)componentMap[c - 'a'];
        if (type != Component.Unused && (format.flags & (1 << type)) != 0)
            return "Duplicate component types not allowed";
        elementTypes[numElements++] = type;
        hasSharedExponent |= type == Component.Exponent;
        str = str[1 .. $];
    }
    if (numElements == 0)
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

    // parse/process components...
    format.componentIndex[] = -1;
    if (str.length > 0)
    {
        import wg.util.parse : parseInt;

        // TODO: handle block-compression formats...

        // no block compression
        ubyte offset = 0;
        ubyte numComponents = 0;
        for (size_t i = 0; i < numElements; ++i)
        {
            if (str.length < 2 || str[0] != '_')
                return "Invalid format string";
            if (numComponents >= RGBFormatDescriptor.componentData.length)
                return "RGB formats may have a maximum of 5 components";

            RGBFormatDescriptor.ComponentDesc component = RGBFormatDescriptor.ComponentDesc(elementTypes[i]);

            // check if the type is qualified
            switch (str[1])
            {
                case 's': component.format = Format.SignedNormInt;  goto skipTwo;
                case 'f': component.format = Format.FloatingPoint;  goto skipTwo;
                case 'u': component.format = Format.UnsignedInt;    goto skipTwo;
                case 'i': component.format = Format.SignedInt;      goto skipTwo;
                skipTwo: str = str[2 .. $]; break;
                default: str = str[1 .. $]; break;
            }

            // parse the component size
            size_t taken = str.parseInt(component.bits);
            if (!taken)
                return "Invalid component descriptor";
            if (component.bits == 0)
                return "Invalid component size: 0";
            str = str[taken .. $];

            component.offset = offset;
            offset += component.bits;

            // if it's fixed point
            if (str.length && str[0] == '.')
            {
                // validate the format
                if (component.format == Format.NormInt)
                    component.format = Format.FixedPoint;
                else if (component.format == Format.SignedNormInt)
                    component.format = Format.SignedFixedPoint;
                else if (component.format != Format.FloatingPoint)
                    return "Fractional components may only be unsigned, signed, or floating point (ie, `4.4`, `s4.4` or `f3.7`)";

                // parse the fractional size
                taken = str[1 .. $].parseInt(component.fracBits);
                if (!taken)
                    return "Invalid component descriptor";
                if (component.fracBits == 0)
                    return "Invalid fractional bits: 0";
                component.bits += component.fracBits;
                str = str[1 + taken .. $]; // include the '.'
            }

            // skip unused components
            if (elementTypes[i] == Component.Unused)
            {
                if (component.format != Format.NormInt)
                    return "Unused ('x') components may not have qualified component type";
                continue;
            }

            // if it has a shared exponent, then assert the rules
            if (hasSharedExponent)
            {
                if (component.format != Format.NormInt)
                    return "Shared exponent formats may not have qualified component types";
                component.format = component.type == Component.Exponent ? Format.Exponent : Format.Mantissa;
            }

            // write component
            format.componentIndex[elementTypes[i]] = numComponents;
            format.componentData[numComponents++] = component;
        }
        format.numComponents = numComponents;

        if (str.length)
            return "Invalid RGB format string";
    }
    else
    {
        ubyte offset = 0;
        ubyte numComponents = 0;
        for (size_t i = 0; i < numElements; ++i)
        {
            if (numComponents >= RGBFormatDescriptor.componentData.length)
                return "RGB formats may have a maximum of 5 components";

            if (elementTypes[i] != Component.Unused)
            {
                format.componentData[numComponents].type = elementTypes[i];
                format.componentData[numComponents].format = Format.NormInt;
                format.componentData[numComponents].offset = offset;
                format.componentData[numComponents].bits = 8;
                format.componentIndex[elementTypes[i]] = numComponents++;
            }

            offset += 8;
        }
        format.numComponents = numComponents;
    }

    // prep the detail data...
    bool allAligned = true;
    ubyte sameSize = format.componentData[0].bits;
    bool sameFormat = true;
    uint numFloating = 0;
    foreach (ref c; format.components)
    {
        format.bits += c.bits;
        allAligned = allAligned && isAlignedType(c.bits);
        sameSize = c.bits == sameSize ? sameSize : 0;
        sameFormat = sameFormat && c.format == format.componentData[0].format;
        numFloating += c.format == Format.FloatingPoint ? 1 : 0;
        if (c.format == Format.FloatingPoint && c.fracBits == 0)
        {
            if (c.bits < 10)
                return "Tiny floats must specifiy mantissa bits (ie, `f3.5`)";
            // we'll guess that packed floats have 5-bit exponent (all common small-floats use 5bit exponent)
            // we'll also guess that floats < 16bits are unsigned for now (format should be able to specify)
//            c.fracBits = cast(ubyte)(c.bits - 5 - (c.bits >= 16));
        }
    }
    if (hasSharedExponent)
    {
        format.alignment = format.bits;
        format.flags |= Flags.AnyFloating | Flags.AllFloating;
    }
    else
    {
        format.alignment = allAligned && sameSize != 0 ? sameSize : format.bits;
        if (numFloating == format.numComponents)
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
    if (format.has(Component.Luma) && (format.has(Component.Red) || format.has(Component.Green) || format.has(Component.Blue)))
        return "RGB colors may not have both 'r/g/b' and 'l' channels";

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
