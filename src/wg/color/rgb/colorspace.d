/**
 This module defines and operates on RGB color spaces.
 
 Authors:    Manu Evans
 Copyright:  Copyright (c) 2016, Manu Evans.
 License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module wg.color.rgb.colorspace;

import wg.color.xyz : xyY;

import wg.util.traits : isFloatingPoint;


/**
 Parameters that define an RGB color space.$(BR)
 $(D_INLINECODE F) is the float type that should be used for the colors and gamma functions.
 */
struct RGBColorSpace
{
    /** Color space identifier. */
    string id;

    /** Color space name. */
    string name;

    /** Functions that converts linear luminance to/from gamma space. */
    GammaFuncPair!float gamma;

    /** White point. */
    xyY white;
    /** Red point. */
    xyY red;
    /** Green point. */
    xyY green;
    /** Blue point. */
    xyY blue;
}

/**
 Pair of gamma functions.
 */
struct GammaFuncPair(F) if (isFloatingPoint!F)
{
    /** Gamma conversion function type. */
    alias GammaFunc = F function(F v) pure nothrow @nogc @safe;

    /** Name for the gamma function */
    string name;

    /** Function that converts a linear luminance to gamma space. */
    GammaFunc toGamma;
    /** Function that converts a gamma luminance to linear space. */
    GammaFunc toLinear;
}
