/**
 This module defines and operates on RGB color spaces.
 
 Authors:    Manu Evans
 Copyright:  Copyright (c) 2016, Manu Evans.
 License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module wg.color.rgb.colorspace;

import wg.color.xyz : xyY;

import wg.util.format : formatReal;
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


/** Linear to gamma transfer function. */
T linearToGamma(double gamma, T)(T v) if (isFloatingPoint!T)
{
    return v^^T(1.0/gamma);
}
/** Linear to gamma transfer function. */
T linearToGamma(T)(T v, T gamma) if (isFloatingPoint!T)
{
    return v^^T(1.0/gamma);
}

/** Gamma to linear transfer function. */
T gammaToLinear(double gamma, T)(T v) if (isFloatingPoint!T)
{
    return v^^T(gamma);
}
/** Gamma to linear transfer function. */
T gammaToLinear(T)(T v, T gamma) if (isFloatingPoint!T)
{
    return v^^T(gamma);
}

/** Linear to hybrid linear-gamma transfer function. The function and parameters are detailed in the example below. */
T linearToHybridGamma(double a, double b, double s, double e, T)(T v) if (isFloatingPoint!T)
{
    if (v <= T(b))
        return v*T(s);
    else
        return T(a)*v^^T(e) - T(a - 1);
}
///
unittest
{
    // sRGB parameters
    enum a = 1.055;
    enum b = 0.0031308;
    enum s = 12.92;
    enum e = 1/2.4;

    double v = 0.5;

    // the gamma function
    if (v <= b)
        v = v*s;
    else
        v = a*v^^e - (a - 1);

    assert(abs(v - linearToHybridGamma!(a, b, s, e)(0.5)) < double.epsilon);
}

/** Hybrid linear-gamma to linear transfer function. The function and parameters are detailed in the example below. */
T hybridGammaToLinear(double a, double b, double s, double e, T)(T v) if (isFloatingPoint!T)
{
    if (v <= T(b*s))
        return v * T(1/s);
    else
        return ((v + T(a - 1)) * T(1/a))^^T(e);
}
///
unittest
{
    // sRGB parameters
    enum a = 1.055;
    enum b = 0.0031308;
    enum s = 12.92;
    enum e = 2.4;

    double v = 0.5;

    // the gamma function
    if (v <= b*s)
        v = v/s;
    else
        v = ((v + (a - 1)) / a)^^e;

    assert(abs(v - hybridGammaToLinear!(a, b, s, e)(0.5)) < double.epsilon);
}

/** Linear transfer functions. (these are a no-op, conversion from linear <-> linear is the `^^1` function) */
enum gammaPair_Linear(F) = GammaFuncPair!F("1", null, null);

/** Gamma transfer functions. */
enum gammaPair_Gamma(double gamma, F) = GammaFuncPair!F(formatReal!double(gamma, 2), &linearToGamma!(gamma, F), &gammaToLinear!(gamma, F));

/** Pparametric hybrid linear-gamma transfer functions. */
enum gammaPair_HybridGamma(string name, double a, double b, double s, double e, F) = GammaFuncPair!F(name, &linearToHybridGamma!(a, b, s, e, F), &hybridGammaToLinear!(a, b, s, 1 / e, F));

/** sRGB hybrid linear-gamma transfer functions. */
enum gammaPair_sRGB(F)  = gammaPair_HybridGamma!("sRGB", 1.055, 0.0031308, 12.92, 1/2.4, F);

/** Rec.601 hybrid linear-gamma transfer functions. Note, Rec.709 also uses these functions. */
enum gammaPair_Rec601(F) = gammaPair_HybridGamma!("Rec.601", 1.099, 0.018, 4.5, 0.45, F);

/** Rec.2020 hybrid linear-gamma transfer functions. */
enum gammaPair_Rec2020(F) = gammaPair_HybridGamma!("Rec.2020", 1.09929682680944, 0.018053968510807, 4.5, 0.45, F);
