
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

/// Template struct representing function result for functions that may return error
struct Result(T, EC = ubyte) if (EC() == 0)
{
    ///
    this()(auto ref T value)
    {
        import core.lifetime;
        this.value = forward!value;
    }
    ///
    this(EC error, string message = "Failed", string file = __FILE__, int line = __LINE__)
    {
        assert(error != EC());
        this.error = error;
        this.line = line;
        this.file = file;
        this.message = message;
    }

    ///
    ref inout(T) unwrap() inout pure @safe
    {
        import core.lifetime : move;
        import core.exception;

        if (error != EC())
            throw new Exception(message, file, line);
        return value;
    }

    ///
    bool opCast(T : bool)() const pure nothrow @safe
    {
        return error == EC();
    }

    /// Result value
    T value;
    /// Error code
    EC error;
    ///
    int line;
    ///
    string file;
    /// Error message in case of an error, null otherwise
    string message;
}
///
unittest
{
    // test success case
    auto r1 = Result!int(10);
    assert(r1 && r1.value == 10 && r1.error == 0);
    try
    {
        int x = r1.unwrap;
        assert(x == 10);
    }
    catch(Exception e)
    {
        assert(false);
    }

    // test fail case
    auto r2 = Result!int(1, "failed!");
    assert(!r2 && r2.error != 0);
    try
    {
        r2.unwrap;
        assert(false);
    }
    catch(Exception e)
    {
        assert(e.msg[] == "failed!");
    }

    // with custom error enum
    enum ErrorCode : ubyte
    {
        success,
        failure
    }

    auto r3 = Result!(int, ErrorCode)(20);
    assert(r3 && r3.value == 20 && r3.error == ErrorCode.success);

    auto r4 = Result!(int, ErrorCode)(ErrorCode.failure, "failed!");
    assert(!r4 && r4.error == ErrorCode.failure);
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
