
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

///
enum ErrorCode : ubyte
{
    ///
    success = 0,
    ///
    failure = 1
}

/// Template struct representing function result for functions that may return error
struct Result(T, EC = ErrorCode) if (is(typeof(EC.success)))
{
    ///
    this()(auto ref T value)
    {
        import core.lifetime;
        this.value = forward!value;
    }
    ///
    this(EC error, string message = "Failed")
    {
        assert(error != EC.success);
        this.error = error;
        this.message = message;
    }

    ///
    ref inout(T) unwrap() inout pure @safe
    {
        import core.lifetime : move;
        import core.exception;

        if (error != EC.success)
            throw new Exception(message);
        return value;
    }

    ///
    bool opCast(T : bool)() const pure nothrow @safe
    {
        return error == EC.success;
    }

    /// Result value
    T value;
    /// Error code
    EC error;
    /// Error message in case of an error, null otherwise
    string message;
}
unittest
{
    auto r1 = Result!int(10);
    assert(r1 && r1.error == ErrorCode.success);
    try
    {
        int x = r1.unwrap;
        assert(x == 10);
    }
    catch(Exception e)
    {
        assert(false);
    }

    auto r2 = Result!int(ErrorCode.failure, "failed!");
    assert(!r2 && r2.error ==ErrorCode.failure);
    try
    {
        r2.unwrap;
        assert(false);
    }
    catch(Exception e)
    {
        assert(e.msg[] == "failed!");
    }
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
