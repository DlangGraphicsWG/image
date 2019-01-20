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

import wg.util.traits : isFloatingPoint;

/**
A CIE 1931 XYZ color, parameterised for component type.
*/
struct XYZ(F = float) if (isFloatingPoint!F)
{
@safe pure nothrow @nogc:

    /** Type of the color components. */
    alias ComponentType = F;

    /** X value. */
    F X = 0;
    /** Y value. */
    F Y = 0;
    /** Z value. */
    F Z = 0;
}

/**
A CIE 1931 xyY color, parameterised for component type.
*/
struct xyY(F = float) if (isFloatingPoint!F)
{
@safe pure nothrow @nogc:

    /** Type of the color components. */
    alias ComponentType = F;

    /** x coordinate. */
    F x = 0;
    /** y coordinate. */
    F y = 0;
    /** Y value (luminance). */
    F Y = 0;
}
