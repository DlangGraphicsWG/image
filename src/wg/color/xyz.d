/**
This module implements $(LINK2 https://en.wikipedia.org/wiki/CIE_1931_color_space, CIE XYZ) and
$(LINK2 https://en.wikipedia.org/wiki/CIE_1931_color_space#CIE_xy_chromaticity_diagram_and_the_CIE_xyY_color_space, xyY)
_color types.

These _color spaces represent the simplest expression of the full-spectrum of human visible _color.
No attempts are made to support perceptual uniformity, or meaningful _color blending within these _color spaces.
They are most useful as an absolute representation of human visible colors, and a centre point for _color space
conversions.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module wg.color.xyz;
import wg.util.parse : skipWhite, parseReal;

/**
Determine if T is an XYZ color type.
*/
enum IsXYZ(T) = is(T == XYZ) || is(T == xyY);

/**
Get the format string for an XYZ or xyY color type.
*/
template FormatString(T) if (IsXYZ!T)
{
    enum FormatString = T.stringof;
}

/**
A CIE 1931 XYZ color.
*/
struct XYZ
{
@safe pure nothrow @nogc:

    /// X value.
    float X = 0;
    /// Y value.
    float Y = 0;
    /// Z value.
    float Z = 0;
}

/**
A CIE 1931 xyY color.
*/
struct xyY
{
@safe pure nothrow @nogc:
    alias ParentColor = XYZ;

    /// x coordinate.
    float x = 0;
    /// y coordinate.
    float y = 0;
    /// Y value (luminance).
    float Y = 0;
}

/**
Parse XYZ/xyY color from string.

TODO: should this be in `wg/color/xyz/parse.d`?
*/
XYZType parseXYZ(XYZType)(const(char)[] str) @safe pure
    if (is(XYZType == XYZ) || is(XYZType == xyY))
{
    import std.exception : enforce;

    XYZType r;
    enforce(str.parseXYZ(r) > 0, "Invalid " ~ XYZType.stringof ~ " color string: " ~ str);
    return r;
}

/**
Parse XYZ/xyY color from string.
*/
size_t parseXYZ(XYZType)(const(char)[] str, out XYZType color) @trusted pure nothrow @nogc
    if (is(XYZType == XYZ) || is(XYZType == xyY))
{
    const(char)[] s = str;
    if (s.length == 0 || s[0] != '{')
        return 0;
    s = s[1 .. $].skipWhite();

    // parse X/x
    size_t taken = s.parseReal(color.tupleof[0]);
    if (!taken)
        return 0;
    s = s[taken .. $].skipWhite();
    if (!s.length || s[0] != ',')
        return 0;
    s = s[1 .. $].skipWhite();

    // parse Y/y
    taken = s.parseReal(color.tupleof[1]);
    if (!taken)
        return 0;
    s = s[taken .. $].skipWhite();
    if (!s.length || (is(XYZType == XYZ) && s[0] != ','))
        return 0;
    if (s[0] == ',')
    {
        // parse Z/Y
        s = s[1 .. $].skipWhite();
        taken = s.parseReal(color.tupleof[2]);
        if (!taken)
            return 0;
        s = s[taken .. $].skipWhite();
        if (!s.length)
            return 0;
    }
    else
        color.tupleof[2] = 1;
    if (s[0] != '}')
        return 0;
    return s.ptr + 1 - str.ptr;
}


package:

XYZ convertColorImpl(Dest)(xyY color) if(is(Dest == XYZ))
{
    if (color.y == 0)
        return XYZ(0, 0, 0);
    else
        return XYZ((color.Y / color.y)*color.x, color.Y, (color.Y / color.y)*(1 - color.x - color.y));
}
unittest
{
    static assert(convertColorImpl!XYZ(xyY(0.5, 0.5, 1)) == XYZ(1, 1, 0));

    // degenerate case
    static assert(convertColorImpl!XYZ(xyY(0.5, 0, 1)) == XYZ(0, 0, 0));
}

xyY convertColorImpl(Dest)(XYZ color) if(is(Dest == xyY))
{
    import wg.color.standard_illuminant : StandardIlluminant;

    float sum = color.X + color.Y + color.Z;
    if (sum == 0)
        return xyY(StandardIlluminant.D65.x, StandardIlluminant.D65.y, 0);
    else
        return xyY(color.X / sum, color.Y / sum, color.Y);
}
unittest
{
    static assert(convertColorImpl!xyY(XYZ(0.5, 1, 0.5)) == xyY(0.25, 0.5, 1));

    // degenerate case
    import wg.color.standard_illuminant : StandardIlluminant;
    static assert(convertColorImpl!xyY(XYZ(0, 0, 0)) == xyY(StandardIlluminant.D65.x, StandardIlluminant.D65.y, 0));
}


void registerXYZ()
{
    import wg.image.format : registerImageFormatFamily;
    import wg.image.imagebuffer : ImageBuffer;

    static bool getImageParams(const(char)[] format, uint width, uint height, out ImageBuffer image) nothrow @nogc @safe
    {
        if (format[] != "XYZ" && format[] != "xyY")
            return false;

        // the following code assumes they are the same size
        assert(XYZ.sizeof == xyY.sizeof);

        image.width = width;
        image.height = height;
        image.bitsPerBlock = XYZ.sizeof * 8;
        image.rowPitch = cast(uint)(width * XYZ.sizeof);

        return true;
    }

    registerImageFormatFamily("xyz", &getImageParams);
}
