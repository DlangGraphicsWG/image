
module wg.util.util;


inout(char)[] asDString(inout(char)* cstr) pure nothrow @nogc @trusted
{
    if (!cstr)
        return null;
    size_t len = 0;
    while (cstr[len])
        ++len;
    return cstr[0 .. len];
}

pragma(inline, true):

// the phobos implementations are literally insane!!
T _min(T)(T a, T b) { return a < b ? a : b; }
T _max(T)(T a, T b) { return a > b ? a : b; }
T _clamp(T)(T v, T min, T max) { return v < min ? min : v > max ? max : v; }
