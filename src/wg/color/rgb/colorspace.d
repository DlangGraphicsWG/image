// Written in the D programming language.
/**
This module defines and operates on RGB color spaces.
 
Authors:    Manu Evans
Copyright:  Copyright (c) 2016-2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.color.rgb.colorspace;

import wg.color.standard_illuminant;
import wg.color.xyz : xyY;

import wg.util.allocator;
import wg.util.format : formatReal;
import wg.util.parse : parseReal;
import wg.util.traits : isFloatingPoint;


/**
Parameters that define an RGB color space.$(BR)
$(D_INLINECODE F) is the float type that should be used for the colors and gamma functions.
*/
struct RGBColorSpace
{
    /// Color space identifier.
    const(char)[] id;

    /// Color space name.
    string name;

    /// Gamma compression technique.
    const(char)[] gamma;

    /// White point.
    xyY white;
    /// Red point.
    xyY red;
    /// Green point.
    xyY green;
    /// Blue point.
    xyY blue;

    /// RGB to XYZ conversion matrix.
    float[3][3] rgbToXyz = [0, 0, 0];

    /// XYZ to RGB conversion matrix.
    float[3][3] xyzToRgb = [0, 0, 0];

    /// Construct an RGB color space from primaries and whitepoint.
    this()(const(char)[] id, string name, const(char)[] gamma, auto ref xyY white, auto ref xyY red, auto ref xyY green, auto ref xyY blue) pure nothrow @nogc @safe
    {
        this.id = id;
        this.name = name;
        this.gamma = gamma;
        this.white = white;
        this.red = red;
        this.green = green;
        this.blue = blue;

        import wg.util.math : inverse;
        rgbToXyz = rgbToXyzMatrix(red, green, blue, white);
        xyzToRgb = rgbToXyz.inverse();
    }
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

/**
Pair of named gamma functions from string.
*/
struct GammaFuncPair(const(char)[] func, F = float) if (isFloatingPoint!F)
{
    enum name = func;

    static if (func[] == "sRGB")
    {
        alias toGamma = linearToHybridGamma!(1.055, 0.0031308, 12.92, 1/2.4, F);
        alias toLinear = hybridGammaToLinear!(1.055, 0.0031308, 12.92, 2.4, F);
    }
    else static if (func[] == "Rec.601")
    {
        alias toGamma = linearToHybridGamma!(1.099, 0.018, 4.5, 0.45, F);
        alias toLinear = hybridGammaToLinear!(1.099, 0.018, 4.5, 1/0.45, F);
    }
    else static if (func[] == "Rec.2020")
    {
        alias toGamma = linearToHybridGamma!(1.09929682680944, 0.018053968510807, 4.5, 0.45, F);
        alias toLinear = hybridGammaToLinear!(1.09929682680944, 0.018053968510807, 4.5, 1/0.45, F);
    }
    else static if (func[] == "1")
    {
        alias toGamma = (F v) => v;
        alias toLinear = (F v) => v;
    }
    else static if (isFloatString(func))
    {
        enum F gamma = parseReal!F(func);

        alias toGamma = linearToGamma!(gamma, F);
        alias toLinear = gammaToLinear!(gamma, F);
    }
    else
        static assert(false, "Function is not a named gamma function or a gamma power");
}

/// Linear to gamma transfer function.
T linearToGamma(double gamma, T)(T v) if (isFloatingPoint!T)
{
    return v^^T(1.0/gamma);
}

/// Linear to gamma transfer function.
T linearToGamma(T)(T v, T gamma) if (isFloatingPoint!T)
{
    return v^^T(1.0/gamma);
}

/// Gamma to linear transfer function.
T gammaToLinear(double gamma, T)(T v) if (isFloatingPoint!T)
{
    return v^^T(gamma);
}

/// Gamma to linear transfer function.
T gammaToLinear(T)(T v, T gamma) if (isFloatingPoint!T)
{
    return v^^T(gamma);
}

/// Linear to hybrid linear-gamma transfer function. The function and parameters are detailed in the example below.
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
    import std.math : abs;

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

/// Hybrid linear-gamma to linear transfer function. The function and parameters are detailed in the example below.
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
    import std.math : abs;

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

/**
RGB to XYZ color space transformation matrix.$(BR)
$(D_INLINECODE cs) describes the source RGB color space.
*/
float[3][3] rgbToXyzMatrix()(auto ref xyY red, auto ref xyY green, auto ref xyY blue, auto ref xyY white) pure nothrow @nogc @safe
{
    import wg.color.xyz : XYZ;
    import wg.util.math : multiply, inverse;

    static XYZ toXYZ(xyY c) { return c.y == 0 ? XYZ() : XYZ(c.x / c.y, 1, (1 - c.x - c.y) / c.y); }

    auto r = toXYZ(red);
    auto g = toXYZ(green);
    auto b = toXYZ(blue);

    // build a matrix from the 3 color vectors
    float[3][3] m = [[ r.X, g.X, b.X ],
                     [ r.Y, g.Y, b.Y ],
                     [ r.Z, g.Z, b.Z ]];

    // multiply by the whitepoint
    float[3] w = [ toXYZ(white).tupleof ];
    auto s = multiply(m.inverse(), w);

    // return colorspace matrix (RGB -> XYZ)
    return [[ r.X*s[0], g.X*s[1], b.X*s[2] ],
            [ r.Y*s[0], g.Y*s[1], b.Y*s[2] ],
            [ r.Z*s[0], g.Z*s[1], b.Z*s[2] ]];
}

/**
XYZ to RGB color space transformation matrix.$(BR)
$(D_INLINECODE cs) describes the target RGB color space.
*/
float[3][3] xyzToRgbMatrix()(auto ref xyY red, auto ref xyY green, auto ref xyY blue, auto ref xyY white) pure nothrow @nogc @safe
{
    import wg.util.math : inverse;

    return rgbToXyzMatrix(red, green, blue, white).inverse();
}

/**
Find an RGB color space by name.
*/
immutable(RGBColorSpace)* findRGBColorspace(const(char)[] name) pure nothrow @nogc
{
    foreach (ref a; csAliases)
    {
        if (name[] == a.alias_[])
        {
            name = a.name;
            break;
        }
    }
    foreach (ref def; rgbColorSpaceDefs)
    {
        if (name[] == def.id[])
            return &def;
    }
    return null;
}

///
float toMonochrome(alias cs)(float r, float g, float b) pure
{
    return cs.red.Y*r + cs.green.Y*g + cs.blue.Y*b;
}

///
float toGrayscale(const(RGBColorSpace) cs, T, U, V)(T r, U g, V b) pure
{
    return toGrayscale!cs(cast(float)r, cast(float)g, cast(float)b);
}

/**
Parse RGB color space from string.
*/
RGBColorSpace parseRGBColorSpace(const(char)[] str) @trusted pure
{
    import std.exception : enforce;

    RGBColorSpace r;
    enforce(str.parseRGBColorSpace(r) > 0, "Invalid RGB color space descriptor: " ~ str);

    // dup the strings if they point internally
    if (r.id == str)
        r.id = r.id.idup;
    if (r.gamma.isSubString(str))
        r.gamma = r.gamma.idup;
    return r;
}

/**
Parse RGB color space from string.
*/
RGBColorSpace* parseRGBColorSpace(const(char)[] str, Allocator* allocator) @trusted nothrow @nogc
{
    RGBColorSpace r;
    if (str.parseRGBColorSpace(r) == 0)
        return null;

    bool allocId = r.id == str;
    bool allocGamma = r.gamma.isSubString(str);

    void[] alloc = allocator.allocate(RGBColorSpace.sizeof + (allocId ? r.id.length + 1 : 0) + (allocGamma ? r.gamma.length + 1 : 0));

    RGBColorSpace* cs = cast(RGBColorSpace*)alloc.ptr;
    *cs = r;

    char* tail = cast(char*)(cs + 1);
    if (allocId)
    {
        cs.id = tail[0 .. r.id.length];
        tail[0 .. r.id.length] = r.id[];
        tail[r.id.length] = '\0';
        tail += r.id.length + 1;
    }
    if (allocGamma)
    {
        cs.gamma = tail[0 .. r.gamma.length];
        tail[0 .. r.gamma.length] = r.gamma[];
        tail[r.gamma.length] = '\0';
    }
    return cs;
}

/**
Parse white point from string.
*/
xyY parseWhitePoint(const(char)[] whitePoint) @trusted pure
{
    import std.exception : enforce;

    xyY r;
    enforce(whitePoint.parseWhitePoint(r) > 0, "Invalid whitepoint: " ~ whitePoint);
    return r;
}

/**
Parse white point from string.
*/
size_t parseWhitePoint(const(char)[] whitePoint, out xyY color) @trusted pure nothrow @nogc
{
    import wg.color.xyz : parseXYZ;

    if (!whitePoint.length)
        return 0;

    // check for custom white point
    if (whitePoint[0] == '{')
        return whitePoint.parseXYZ(color);

    // assume a standard illuminant
    if (!whitePoint.getStandardIlluminant(color))
        return 0;

    return whitePoint.length;
}

package:

static immutable RGBColorSpace[] rgbColorSpaceDefs = [
    RGBColorSpace("sRGB",         "sRGB",               "sRGB",     StandardIlluminant.D65, xyY(0.6400, 0.3300, 0.212656), xyY(0.3000, 0.6000, 0.715158), xyY(0.1500, 0.0600, 0.072186)),

    RGBColorSpace("NTSC1953",     "NTSC 1953",          "Rec.601",  StandardIlluminant.C,   xyY(0.6700, 0.3300, 0.299000), xyY(0.2100, 0.7100, 0.587000), xyY(0.1400, 0.0800, 0.114000)),
    RGBColorSpace("NTSC",         "Rec.601 NTSC",       "Rec.601",  StandardIlluminant.D65, xyY(0.6300, 0.3400, 0.299000), xyY(0.3100, 0.5950, 0.587000), xyY(0.1550, 0.0700, 0.114000)),
    RGBColorSpace("NTSC-J",       "Rec.601 NTSC-J",     "Rec.601",  StandardIlluminant.D93, xyY(0.6300, 0.3400, 0.299000), xyY(0.3100, 0.5950, 0.587000), xyY(0.1550, 0.0700, 0.114000)),
    RGBColorSpace("PAL/SECAM",    "Rec.601 PAL/SECAM",  "Rec.601",  StandardIlluminant.D65, xyY(0.6400, 0.3300, 0.299000), xyY(0.2900, 0.6000, 0.587000), xyY(0.1500, 0.0600, 0.114000)),
    RGBColorSpace("Rec.709",      "Rec.709 HDTV",       "Rec.601",  StandardIlluminant.D65, xyY(0.6400, 0.3300, 0.212600), xyY(0.3000, 0.6000, 0.715200), xyY(0.1500, 0.0600, 0.072200)),
    RGBColorSpace("Rec.2020",     "Rec.2020 UHDTV",     "Rec.2020", StandardIlluminant.D65, xyY(0.7080, 0.2920, 0.262700), xyY(0.1700, 0.7970, 0.678000), xyY(0.1310, 0.0460, 0.059300)),

    RGBColorSpace("AdobeRGB",     "Adobe RGB",          "2.2",      StandardIlluminant.D65, xyY(0.6400, 0.3300, 0.297361), xyY(0.2100, 0.7100, 0.627355), xyY(0.1500, 0.0600, 0.075285)),
    RGBColorSpace("WideGamutRGB", "Wide Gamut RGB",     "2.2",      StandardIlluminant.D50, xyY(0.7350, 0.2650, 0.258187), xyY(0.1150, 0.8260, 0.724938), xyY(0.1570, 0.0180, 0.016875)),
    RGBColorSpace("AppleRGB",     "Apple RGB",          "1.8",      StandardIlluminant.D65, xyY(0.6250, 0.3400, 0.244634), xyY(0.2800, 0.5950, 0.672034), xyY(0.1550, 0.0700, 0.083332)),
    RGBColorSpace("ProPhoto",     "ProPhoto",           "1.8",      StandardIlluminant.D50, xyY(0.7347, 0.2653, 0.288040), xyY(0.1596, 0.8404, 0.711874), xyY(0.0366, 0.0001, 0.000086)),
    RGBColorSpace("CIERGB",       "CIE RGB",            "2.2",      StandardIlluminant.E,   xyY(0.7350, 0.2650, 0.176204), xyY(0.2740, 0.7170, 0.812985), xyY(0.1670, 0.0090, 0.010811)),

    RGBColorSpace("P3DCI",        "DCI-P3 Theater",     "2.6",      StandardIlluminant.DCI, xyY(0.6800, 0.3200, 0.228975), xyY(0.2650, 0.6900, 0.691739), xyY(0.1500, 0.0600, 0.079287)),
    RGBColorSpace("P3D65",        "DCI-P3 D65",         "2.6",      StandardIlluminant.D65, xyY(0.6800, 0.3200, 0.228973), xyY(0.2650, 0.6900, 0.691752), xyY(0.1500, 0.0600, 0.079275)),
    RGBColorSpace("P3D60",        "DCI-P3 ACES Cinema", "2.6",      StandardIlluminant.D60, xyY(0.6800, 0.3200, 0.228973), xyY(0.2650, 0.6900, 0.691752), xyY(0.1500, 0.0600, 0.079275)),
    RGBColorSpace("DisplayP3",    "Apple Display P3",   "sRGB",     StandardIlluminant.D65, xyY(0.6800, 0.3200, 0.228973), xyY(0.2650, 0.6900, 0.691752), xyY(0.1500, 0.0600, 0.079275))
];

struct CSAlias { string alias_, name; }
static immutable CSAlias[] csAliases = [
    CSAlias("BT.709",  "Rec.709"),
    CSAlias("HDTV",    "Rec.709"),
    CSAlias("BT.2020", "Rec.2020"),
    CSAlias("UHDTV",   "Rec.2020"),
];

size_t parseRGBColorSpace(const(char)[] str, out RGBColorSpace cs) @trusted pure nothrow @nogc
{
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

    const(char)[] s = str;

    // take optional gamma and whitepoint from back of string
    const(char)[] gamma = popBackToken(s, '^');         // Eg: `^2.4`
    const(char)[] whitePoint = popBackToken(s, '@');    // Eg: `@D65`

    bool buildMatrices = false;

    // find a satandard colour space
    immutable(RGBColorSpace)* found = findRGBColorspace(s);
    if (found)
    {
        cs = *found;
    }
    else
    {
        import wg.color.xyz : parseXYZ;

        // custom colour space in the form: `R{x,y,Y}G{x,y,Y}B{x,y,Y}`

        // parse red-point: `R{x,y,Y}`
        if (!s.length || s[0] != 'R')
            return 0;
        size_t taken = s[1 .. $].parseXYZ!xyY(cs.red);
        if (!taken)
            return 0;
        s = s[1 + taken .. $];

        // parse green-point: `G{x,y,Y}`
        if (!s.length || s[0] != 'G')
            return 0;
        taken = s[1 .. $].parseXYZ!xyY(cs.green);
        if (!taken)
            return 0;
        s = s[1 + taken .. $];

        // parse blue-point: `B{x,y,Y}`
        if (!s.length || s[0] != 'B')
            return 0;
        taken = s[1 .. $].parseXYZ!xyY(cs.blue);
        if (!taken || taken + 1 != s.length)
            return 0;

        // default to sRGB white and gamma
        cs.white = StandardIlluminant.D65;
        cs.gamma = "sRGB";

        buildMatrices = true;
    }

    // parse the gamma and whitepoint overrides
    if (whitePoint.length > 0)
    {
        if (!whitePoint.parseWhitePoint(cs.white))
            return 0;
        buildMatrices = true;
    }
    if (gamma.length > 0)
        cs.gamma = gamma;

    // assign the id if it's non-standard
    if (!found || whitePoint.length > 0 || gamma.length > 0)
        cs.id = str;

    // build the RGB/XYZ conversion matrices
    if (buildMatrices)
    {
        import wg.util.math : inverse;
        cs.rgbToXyz = rgbToXyzMatrix(cs.red, cs.green, cs.blue, cs.white);
        cs.xyzToRgb = cs.rgbToXyz.inverse();
    }

    return str.length;
}

// TODO: put these utility functions somewhere else?
bool isSubString(const(char)[] subStr, const(char)[] str) pure nothrow @nogc @safe
{
    return &str[0] <= &subStr[0] && &str[$-1] >= &subStr[$-1];
}

bool isFloatString(const(char)[] str) pure nothrow @nogc @safe
{
    if (str.length == 0)
        return false;
    if (str[0] == '-' || str[0] == '+')
        str = str[1 .. $];
    bool hasDot = false;
    int numCount = 0;
    foreach (c; str)
    {
        if (c == '.')
        {
            if (hasDot)
                return false;
            hasDot = true;
            numCount = 0;
        }
        else if (c < '0' || c > '9')
            return false;
        else
            ++numCount;
    }
    return numCount > 0;
}
