// Written in the D programming language.
/**
Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.image.format;

import wg.image.imagebuffer;

///
alias GetImageParams = bool function(const(char)[] format, uint width, uint height, out ImageBuffer image) nothrow @nogc @safe;

///
void registerImageFormatFamily(string family, GetImageParams getImageParams)
{
    FormatFamily* formatFamily = new FormatFamily;
    formatFamily.family = family;
    formatFamily.getImageParams = getImageParams;
    formatFamily.next = imageFormats;
    imageFormats = formatFamily;
}

///
string getFormatFamily(const(char)[] format) nothrow @nogc @trusted
{
    FormatFamily* f = imageFormats;
    ImageBuffer image;
    while (f)
    {
        if (f.getImageParams(format, 16, 16, image))
            return f.family;
        f = f.next;
    }
    return null;
}

///
bool getImageParams(const(char)[] format, uint width, uint height, out ImageBuffer image) nothrow @nogc @trusted
{
    for (FormatFamily* f = imageFormats; f; f = f.next)
    {
        if (f.getImageParams(format, width, height, image))
            return true;
    }
    return false;
}

///
template FormatForPixelType(T)
{
    import std.traits : moduleName;

    static if (is(typeof(moduleName!T)))
    {
        // this hack emulates ADL
        mixin("import " ~ moduleName!T ~ ";");
        mixin("alias M = " ~ moduleName!T ~ ";");

        // expect a template called `FormatString` beside every colour type
        static if (is(typeof(M.FormatString!T)))
            enum FormatForPixelType = M.FormatString!T;
        else
            static assert(false, "Unable to determine format for pixel type: " ~ T.stringof ~ ", no `FormatString(T)` specified for type");
    }
    else
        static assert(false, "Unable to determine format for pixel type: " ~ T.stringof ~ ", primitive types not supported");
}

private:

struct FormatFamily
{
    FormatFamily* next;
    string family;
    GetImageParams getImageParams;
}

__gshared FormatFamily* imageFormats;
