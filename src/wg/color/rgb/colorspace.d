/**
 This module defines and operates on RGB color spaces.
 
 Authors:    Manu Evans
 Copyright:  Copyright (c) 2016, Manu Evans.
 License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module wg.color.rgb.colorspace;

import wg.color.standard_illuminant;
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


package:

__gshared immutable RGBColorSpace[] rgbColorSpaceDefs = [
    RGBColorSpace("sRGB",         "sRGB",               gammaPair_sRGB!float,           StandardIlluminant.D65, xyY(0.6400, 0.3300, 0.212656), xyY(0.3000, 0.6000, 0.715158), xyY(0.1500, 0.0600, 0.072186)),

    RGBColorSpace("NTSC1953",     "NTSC 1953",          gammaPair_Rec601!float,         StandardIlluminant.C,   xyY(0.6700, 0.3300, 0.299000), xyY(0.2100, 0.7100, 0.587000), xyY(0.1400, 0.0800, 0.114000)),
    RGBColorSpace("NTSC",         "Rec.601 NTSC",       gammaPair_Rec601!float,         StandardIlluminant.D65, xyY(0.6300, 0.3400, 0.299000), xyY(0.3100, 0.5950, 0.587000), xyY(0.1550, 0.0700, 0.114000)),
    RGBColorSpace("NTSC-J",       "Rec.601 NTSC-J",     gammaPair_Rec601!float,         StandardIlluminant.D93, xyY(0.6300, 0.3400, 0.299000), xyY(0.3100, 0.5950, 0.587000), xyY(0.1550, 0.0700, 0.114000)),
    RGBColorSpace("PAL/SECAM",    "Rec.601 PAL/SECAM",  gammaPair_Rec601!float,         StandardIlluminant.D65, xyY(0.6400, 0.3300, 0.299000), xyY(0.2900, 0.6000, 0.587000), xyY(0.1500, 0.0600, 0.114000)),
    RGBColorSpace("Rec.709",      "Rec.709 HDTV",       gammaPair_Rec601!float,         StandardIlluminant.D65, xyY(0.6400, 0.3300, 0.212600), xyY(0.3000, 0.6000, 0.715200), xyY(0.1500, 0.0600, 0.072200)),
    RGBColorSpace("Rec.2020",     "Rec.2020 UHDTV",     gammaPair_Rec2020!float,        StandardIlluminant.D65, xyY(0.7080, 0.2920, 0.262700), xyY(0.1700, 0.7970, 0.678000), xyY(0.1310, 0.0460, 0.059300)),

    RGBColorSpace("AdobeRGB",     "Adobe RGB",          gammaPair_Gamma!(2.2, float),   StandardIlluminant.D65, xyY(0.6400, 0.3300, 0.297361), xyY(0.2100, 0.7100, 0.627355), xyY(0.1500, 0.0600, 0.075285)),
    RGBColorSpace("WideGamutRGB", "Wide Gamut RGB",     gammaPair_Gamma!(2.2, float),   StandardIlluminant.D50, xyY(0.7350, 0.2650, 0.258187), xyY(0.1150, 0.8260, 0.724938), xyY(0.1570, 0.0180, 0.016875)),
    RGBColorSpace("AppleRGB",     "Apple RGB",          gammaPair_Gamma!(1.8, float),   StandardIlluminant.D65, xyY(0.6250, 0.3400, 0.244634), xyY(0.2800, 0.5950, 0.672034), xyY(0.1550, 0.0700, 0.083332)),
    RGBColorSpace("ProPhoto",     "ProPhoto",           gammaPair_Gamma!(1.8, float),   StandardIlluminant.D50, xyY(0.7347, 0.2653, 0.288040), xyY(0.1596, 0.8404, 0.711874), xyY(0.0366, 0.0001, 0.000086)),
    RGBColorSpace("CIERGB",       "CIE RGB",            gammaPair_Gamma!(2.2, float),   StandardIlluminant.E,   xyY(0.7350, 0.2650, 0.176204), xyY(0.2740, 0.7170, 0.812985), xyY(0.1670, 0.0090, 0.010811)),

    RGBColorSpace("P3DCI",        "DCI-P3 Theater",     gammaPair_Gamma!(2.6, float),   StandardIlluminant.DCI, xyY(0.6800, 0.3200, 0.228975), xyY(0.2650, 0.6900, 0.691739), xyY(0.1500, 0.0600, 0.079287)),
    RGBColorSpace("P3D65",        "DCI-P3 D65",         gammaPair_Gamma!(2.6, float),   StandardIlluminant.D65, xyY(0.6800, 0.3200, 0.228973), xyY(0.2650, 0.6900, 0.691752), xyY(0.1500, 0.0600, 0.079275)),
    RGBColorSpace("P3D60",        "DCI-P3 ACES Cinema", gammaPair_Gamma!(2.6, float),   StandardIlluminant.D60, xyY(0.6800, 0.3200, 0.228973), xyY(0.2650, 0.6900, 0.691752), xyY(0.1500, 0.0600, 0.079275)),
    RGBColorSpace("DisplayP3",    "Apple Display P3",   gammaPair_sRGB!float,           StandardIlluminant.D65, xyY(0.6800, 0.3200, 0.228973), xyY(0.2650, 0.6900, 0.691752), xyY(0.1500, 0.0600, 0.079275))
];
