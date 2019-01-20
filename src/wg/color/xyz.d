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
