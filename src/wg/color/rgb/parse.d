module wg.color.rgb.parse;

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
