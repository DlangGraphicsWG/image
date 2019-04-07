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
    FormatFamily* f = imageFormats;
    while (f)
    {
        if (f.getImageParams(format, width, height, image))
            return true;
        f = f.next;
    }
    return false;
}

///
template FormatForPixelType(T)
{
    // this hack emulates ADL
    import std.traits : moduleName;
    mixin("import " ~ moduleName!T ~ ";");
    mixin("alias M = " ~ moduleName!T ~ ";");

    // expect a template called `FormatString` beside every colour type
    enum FormatForPixelType = M.FormatString!T;
}

private:

struct FormatFamily
{
    FormatFamily* next;
    string family;
    GetImageParams getImageParams;
}

__gshared FormatFamily* imageFormats;
