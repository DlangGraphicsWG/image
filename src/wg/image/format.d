module wg.image.format;

template formatForPixelType(T)
{
    // TODO: real pixel formats would have special string conversions

    // ie: struct { ubyte r, g, b, a; }
    //  -> "RGBA_8_8_8_8"

    // HACK
    enum formatForPixelType = T.stringof;
}
