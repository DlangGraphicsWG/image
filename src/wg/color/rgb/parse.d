module wg.color.rgb.parse;

import wg.color.rgb.colorspace;
import wg.color.standard_illuminant;
import wg.color.xyz;

// TODO: should these functions just be `float` instead of `F`?
/**
 * Parse white point from string.
 */
xyY!F parseWhitePoint(F = float)(const(char)[] whitePoint) @trusted pure
{
    xyY!F r;
    assert(whitePoint.parseWhitePoint(r) > 0); // enforce
    return r;
}

/**
 * Parse white point from string.
 */
size_t parseWhitePoint(F = float)(const(char)[] whitePoint, out xyY!F color) @trusted pure nothrow @nogc
{
    if (!whitePoint.length)
        return 0;

    // check for custom white point
    if (whitePoint[0] == '{')
        return whitePoint.parseXYZ(color);

    // assume a standard illuminant
    static if (is(F == float))
    {
        // `float` path, support NRVO!
        if (!whitePoint.getStandardIlluminant(color))
            return 0;
    }
    else
    {
        // convert to higher-precision
        xyY!float r;
        if (!whitePoint.getStandardIlluminant(r))
            return 0;
        color = xyY!F(r.x, r.y, r.Y);
    }

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
