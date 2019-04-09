// Written in the D programming language.
/**
RGB colour conversion.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.color.rgb.convert;

import wg.color.rgb;

/**
* Unpack RGB color to float.
* 
* Params:
* $(D_INLINECODE element) = An RGB image element.
* $(D_INLINECODE format) = An RGB format descriptor for the element.
*/
float[4] unpackRgbColor(bool outputLinear = false)(const(void)[] element, ref const(RGBFormatDescriptor) format)
    in(element.length == format.bits / 8)
{
    import wg.util.packedfloat;
    import wg.util.util : _max;

    float[4] r = void;

    // determine component indices
    int[4] cmpIndex = void;
    cmpIndex[0] = format.componentIndex[RGBFormatDescriptor.Component.Luma];
    if (cmpIndex[0] >= 0)
        cmpIndex[1] = cmpIndex[2] = cmpIndex[0];
    else
    {
        cmpIndex[0] = format.componentIndex[RGBFormatDescriptor.Component.Red];
        cmpIndex[1] = format.componentIndex[RGBFormatDescriptor.Component.Green];
        cmpIndex[2] = format.componentIndex[RGBFormatDescriptor.Component.Blue];
    }
    cmpIndex[3] = format.componentIndex[RGBFormatDescriptor.Component.Alpha];

    // check for fast-path
    if ((format.flags & (RGBFormatDescriptor.Flags.AllAligned | RGBFormatDescriptor.Flags.AllSameSize)) == (RGBFormatDescriptor.Flags.AllAligned | RGBFormatDescriptor.Flags.AllSameSize))
    {
        static float[4] unpack(U, S, F)(const(void)* element, ref int[4] index, ref const(RGBFormatDescriptor) format)
        {
            enum bits = U.sizeof * 8;
            float[4] r = void;
            switch (format.componentData[0].format)
            {
                case RGBFormatDescriptor.Format.NormInt:
                    static foreach (i; 0 .. 4)
                        r[i] = index[i] >= 0 ? (cast(U*)element)[format.componentData[index[i]].offset / bits] * (1.0f/U.max) : 0.0f;
                    break;
                case RGBFormatDescriptor.Format.SignedNormInt:
                    static foreach (i; 0 .. 4)
                        r[i] = index[i] >= 0 ? _max((cast(S*)element)[format.componentData[index[i]].offset / bits] * (1.0f/S.max), -1.0f) : 0.0f;
                    break;
                case RGBFormatDescriptor.Format.FloatingPoint:
                    static if (!is(F == void))
                    {
                        static foreach (i; 0 .. 4)
                            r[i] = index[i] >= 0 ? cast(float)(cast(F*)element)[format.componentData[index[i]].offset / bits] : 0.0f;
                        break;
                    }
                    else
                        assert(false, "TODO: what should this do?");
                case RGBFormatDescriptor.Format.FixedPoint:
                    static foreach (i; 0 .. 4)
                        r[i] = index[i] >= 0 ? (cast(U*)element)[format.componentData[index[i]].offset / bits] * (1.0f/(1 << format.componentData[index[i]].fracBits)) : 0.0f;
                    break;
                case RGBFormatDescriptor.Format.SignedFixedPoint:
                    static foreach (i; 0 .. 4)
                        r[i] = index[i] >= 0 ? (cast(S*)element)[format.componentData[index[i]].offset / bits] * (1.0f/(1 << format.componentData[index[i]].fracBits)) : 0.0f;
                    break;
                case RGBFormatDescriptor.Format.UnsignedInt:
                    static foreach (i; 0 .. 4)
                        r[i] = index[i] >= 0 ? cast(float)(cast(U*)element)[format.componentData[index[i]].offset / bits] : 0.0f;
                    break;
                case RGBFormatDescriptor.Format.SignedInt:
                    static foreach (i; 0 .. 4)
                        r[i] = index[i] >= 0 ? cast(float)(cast(S*)element)[format.componentData[index[i]].offset / bits] : 0.0f;
                    break;
                default:
                    assert(false, "how did this happen?");
            }
            return r;
        }

        // simple case
        switch (format.componentData[0].bits / 8)
        {
            case 1:
                r = unpack!(ubyte, byte, void)(element.ptr, cmpIndex, format);
                break;
            case 2:
                r = unpack!(ushort, short, PackedFloat!(ushort, 16, true, 5))(element.ptr, cmpIndex, format);
                break;
            case 4:
                r = unpack!(uint, int, float)(element.ptr, cmpIndex, format);
                break;
            case 8:
                r = unpack!(ulong, long, double)(element.ptr, cmpIndex, format);
                break;
            default:
                assert(false, "TODO: how did we get here?");
        }
    }
    else
    {
        static float unpack(ulong bits, ref const(RGBFormatDescriptor.ComponentDesc) component) pure nothrow @nogc
        {
            ulong mask = (1 << component.bits) - 1;
            switch(component.format)
            {
                case RGBFormatDescriptor.Format.NormInt:
                    bits = (bits >> component.offset) & mask;
                    return bits / float(mask);

                case RGBFormatDescriptor.Format.SignedNormInt:
                    long sbits = bits << (64 - component.offset - component.bits);
                    sbits = (sbits >> (64 - component.bits)) & mask;
                    return _max(sbits / float(mask >> 1), -1.0f);

                case RGBFormatDescriptor.Format.FloatingPoint:
                    assert(false, "TODO: gotta do packed small-floats...");

                case RGBFormatDescriptor.Format.FixedPoint:
                    bits = (bits >> component.offset) & mask;
                    return bits / float(1 << component.fracBits);

                case RGBFormatDescriptor.Format.SignedFixedPoint:
                    long sbits = bits << (64 - component.offset - component.bits);
                    sbits = (sbits >> (64 - component.bits)) & mask;
                    return sbits / float(1 << component.fracBits);

                case RGBFormatDescriptor.Format.UnsignedInt:
                    bits = (bits >> component.offset) & mask;
                    return cast(float)bits;

                case RGBFormatDescriptor.Format.SignedInt:
                    long sbits = bits << (64 - component.offset - component.bits);
                    sbits = (sbits >> (64 - component.bits)) & mask;
                    return cast(float)sbits;
                default:
                    assert(false);
            }
        }

        // bit packed
        byte expIndex = format.componentIndex[RGBFormatDescriptor.Component.Exponent];
        assert(expIndex < 0, "TODO: shared exponent...");

        ulong bits;
        switch (element.length)
        {
            case 1: bits = *cast(ubyte*)element.ptr; break;
            case 2: bits = *cast(ushort*)element.ptr; break;
            case 4: bits = *cast(uint*)element.ptr; break;
            case 8: bits = *cast(ulong*)element.ptr; break;
            default: (cast(void*)&bits)[0 .. element.length] = element[]; break;
        }
        static foreach (i; 0 .. 4)
            r[i] = cmpIndex[i] >= 0 ? unpack(bits, format.componentData[cmpIndex[i]]) : 0.0f;
    }

    static if (outputLinear)
    {
        static assert(false, "TODO: do gamma conversion...");
    }

    return r;
}
