module wg.util.parse;

/**
 * Skip characters.
 */
inout(char)[] skip(string chars)(inout(char)[] s) @safe pure nothrow @nogc
{
    outer: foreach (i; 0 .. s.length)
    {
        foreach (c; chars)
            if (s[i] == c)
                continue outer;
        return s[i .. $];
    }
    // all characters were skipped!
    return s[$ .. $];
}

/**
 * Skip whitespace characters. (but not newlines)
 */
alias skipWhite = skip!" \t";


/**
* Parse real from string.
*/
I parseInt(I)(const(char)[] str) @safe pure
{
    I r;
    assert(str.parseInt(r) > 0); // TODO: enforce instead of assert
    return r;
}

/**
* Parse real from string.
*/
size_t parseInt(I)(const(char)[] str, out I num) @trusted pure nothrow @nogc
{
    const(char)[] s = str;
    if (s.length == 0)
        return 0;
    bool neg = s[0] == '-';
    if (s[0] == '-' || s[0] == '+')
        s = s[1 .. $];
    long value = 0;
    size_t i = 0;
    while (i < s.length && s[i] >= '0' && s[i] <= '9')
    {
        value = value*10 + cast(ubyte)(s[i] - '0');
        ++i;
    }
    if (i == 0)
        return 0;
    num = neg ? cast(I)-value : cast(I)value;
    return s.ptr + i - str.ptr;
}


/**
 * Parse real from string.
 */
F parseReal(F)(const(char)[] str) @safe pure
{
    F r;
    assert(str.parseReal(r) > 0); // TODO: enforce instead of assert
    return r;
}

/**
 * Parse real from string.
 */
size_t parseReal(F)(const(char)[] str, out F num) @trusted pure nothrow @nogc
{
    const(char)[] s = str;
    if (s.length == 0)
        return 0;
    bool neg = s[0] == '-';
    if (s[0] == '-' || s[0] == '+')
        s = s[1 .. $];
    long value = 0;
    int divisor = 0;
    size_t i = 0;
    while (i < s.length)
    {
        if ((s[i] < '0' || s[i] > '9') && (s[i] != '.' || divisor != 0))
            break;
        if (s[i] == '.')
            divisor = 1;
        else
        {
            value = value*10 + cast(ubyte)(s[i] - '0');
            if (divisor)
                divisor *= 10;
        }
        ++i;
    }
    if (i == 0 || divisor == 1)
        return 0;
    if (neg)
        value = -value;
    num = !divisor ? cast(F)value : cast(F)value / divisor;
    return s.ptr + i - str.ptr;
}
