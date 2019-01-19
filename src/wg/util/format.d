module wg.util.format;

import wg.util.traits : isSigned;

/**
 * Format an integer as a string.
 */
string formatInt(I)(I i, uint minSize = 0) @safe pure nothrow
{
    char[21] buffer;
    char[] r = formatInt!I(i, buffer, minSize);
    return cast(string)null ~ r;
}

/**
 * Format an integer as a string.
 */
char[] formatInt(I)(I i, ref char[21] output, uint minSize = 0) @safe pure nothrow @nogc
{
    assert(minSize <= 20, "Too many digits!");

    uint numDigits = 0;
    if (i == 0)
    {
        if (minSize == 0)
            minSize = 1;
        output[$ - minSize .. $] = '0';
        numDigits = minSize;
    }
    else
    {
        static if (isSigned!I)
        {
            bool neg = i < 0;
            if (neg)
                i = cast(I)-cast(int)i;
            bool overflow = i < 0;
            if (overflow) // it's STILL negative if it's == I.min
                i = I.max;
        }
        while (i)
        {
            output[$ - ++numDigits] = '0' + i % 10;
            i /= 10;
        }
        while (numDigits < minSize)
            output[$ - ++numDigits] = '0';
        static if (isSigned!I)
        {
            if (neg)
                output[$ - ++numDigits] = '-';
            if (overflow)
                ++output[$ - 1];
        }
    }
    return output[$ - numDigits .. $];
}

/**
 * Format a real as a string.
 */
string formatReal(F)(F f, uint decimals = 3) @safe pure nothrow
{
    char[22] buffer;
    char[] r = formatReal!F(f, buffer, decimals);
    return cast(string)null ~ r;
}

/**
 * Format a real as a string.
 */
char[] formatReal(F)(F f, ref char[22] output, uint decimals = 3) @trusted pure nothrow @nogc
{
    assert(decimals <= 20, "Too many decimal places!");

    if (decimals)
    {
        // multiply decimal places into integer space
        ulong mul = 10;
        foreach (_; 1 .. decimals)
            mul *= 10;
        f = f * F(mul) + (f < 0 ? F(-0.5) : F(0.5)); // round up
    }

    // TODO: if (f > long.max) { ... we have a problem ... }
    //       support scientific notation? or something?

    long i = cast(long)f;
    char[] r = formatInt(i, output[0 .. 21], decimals + 1);

    // trincate trailing '0's
    while (decimals && r[$ - 1] == '0')
    {
        --decimals;
        r = r[0 .. $ - 1];
    }
    if (decimals)
    {
        // shift digits one character to the right and insert the decimal point
        r = r.ptr[0 .. r.length + 1]; // extend by 1 byte for decimal point
        for (size_t j = r.length - 1; j >= r.length - decimals; --j)
            r[j] = r[j - 1];
        r[$ - decimals - 1] = '.';
    }
    return r;
}
