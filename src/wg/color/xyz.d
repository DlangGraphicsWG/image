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
*/
module wg.color.xyz;

import wg.util.parse : skipWhite, parseReal;

/**
A CIE 1931 XYZ color, parameterised for component type.
*/
struct XYZ
{
@safe pure nothrow @nogc:

    /** X value. */
    float X = 0;
    /** Y value. */
    float Y = 0;
    /** Z value. */
    float Z = 0;
}

/**
A CIE 1931 xyY color, parameterised for component type.
*/
struct xyY
{
@safe pure nothrow @nogc:

    /** x coordinate. */
    float x = 0;
    /** y coordinate. */
    float y = 0;
    /** Y value (luminance). */
    float Y = 0;
}


// TODO: should this be in `wg/color/xyz/parse.d`?
/**
 * Parse XYZ/xyY color from string.
 */
XYZType parseXYZ(XYZType)(const(char)[] str) @safe pure
    if (is(XYZType == XYZ) || is(XYZType == xyY))
{
    XYZType r;
    assert(str.parseXYZ(r) > 0, "Invalid " ~ XYZType.stringof ~ " color string: " ~ str); // TODO: enforce instead of assert
    return r;
}

/**
 * Parse XYZ/xyY color from string.
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
