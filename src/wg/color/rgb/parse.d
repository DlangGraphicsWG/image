module wg.color.rgb.parse;

import wg.color.rgb.colorspace;
import wg.color.standard_illuminant;
import wg.color.xyz;

/**
 * Parse RGB color space from string.
 */
RGBColorSpace parseRGBColorSpace(const(char)[] str) @trusted pure
{
    RGBColorSpace r;
    assert(str.parseRGBColorSpace(r) > 0); // enforce
    return r;
}

/**
 * Parse RGB color space from string.
 */
// TODO: `cs` should be `out`, but that doesn't work with CTFE for some reason!
size_t parseRGBColorSpace(const(char)[] str, ref RGBColorSpace cs) @trusted pure nothrow @nogc
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

    // find a satandard colour space
    immutable(RGBColorSpace)* found = findRGBColorspace(s);
    if (found)
    {
        cs = *found;
    }
    else
    {
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
        cs.gamma = gammaPair_sRGB!float;
    }

    // parse the gamma and whitepoint overrides
    if (whitePoint.length > 0 && !whitePoint.parseWhitePoint(cs.white))
        return 0;
    if (gamma.length > 0 && !gamma.parseGammaFunctions!float(cs.gamma))
        return 0;

    return str.length;
}

// TODO: should these functions just be `float` instead of `F`?
/**
 * Parse white point from string.
 */
xyY parseWhitePoint(const(char)[] whitePoint) @trusted pure
{
    xyY r;
    assert(whitePoint.parseWhitePoint(r) > 0); // enforce
    return r;
}

/**
 * Parse white point from string.
 */
size_t parseWhitePoint(const(char)[] whitePoint, out xyY color) @trusted pure nothrow @nogc
{
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


/**
 * Parse gamma functions from string.
 */
GammaFuncPair!F parseGammaFunctions(F = float)(const(char)[] gamma) @trusted pure
{
    GammaFuncPair!F r;
    assert(gamma.parseGammaFunctions(r) > 0, "Invalid gamma function"); // enforce
    return r;
}

/**
 * Parse gamma functions from string.
 */
size_t parseGammaFunctions(F = float)(const(char)[] gamma, out GammaFuncPair!F gammaFunctions) @trusted pure nothrow @nogc
{
    // gamma power == 1 is the linear function
    if (gamma[] == "1")
        gammaFunctions = gammaPair_Linear!F;

    // TODO: can't generate runtime functions for custom powers. we'll just support common ones for now.
    //       maybe we could make the gamma functions `delegate` and read the power from a closure...
    //       but that would slow down the overwhelmingly common case! :/
    else if (gamma[] == "1.8")
        gammaFunctions = gammaPair_Gamma!(1.8, F);
    else if (gamma[] == "2.2")
        gammaFunctions = gammaPair_Gamma!(2.2, F);
    else if (gamma[] == "2.4")
        gammaFunctions = gammaPair_Gamma!(2.4, F);
    else if (gamma[] == "2.6")
        gammaFunctions = gammaPair_Gamma!(2.6, F);
    else
    {
        // should the gamma functions have their own namespace?
        immutable(RGBColorSpace)* cs = findRGBColorspace(gamma);
        if (!cs)
            return 0;
        gammaFunctions = cs.gamma;
    }
    return gamma.length;
}
