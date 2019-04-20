
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

/// Interprets the given array as an array of another type with proper length
T[] asArrayOf(T, U)(U[] data)
{
    return (cast(T*)data.ptr)[0..U.sizeof * data.length / T.sizeof];
}

unittest
{
    ubyte[] bytes = new ubyte[32];
    immutable floats = bytes.asArrayOf!float();
    assert(floats.length == 32 / float.sizeof);
    assert(floats.ptr == bytes.ptr);
}

/// Template struct representing function result for functions that may return error
struct Result(T)
{
    /// Error message in case of an error, null otherwise
    string error;
    
    /// Useful data, might not be initialized in case error is set
    T value;
    alias value this;
}