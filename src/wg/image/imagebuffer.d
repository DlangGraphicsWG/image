module wg.image.imagebuffer;

import wg.image;
import wg.image.metadata;

struct ImageBuffer
{
    uint width, height;
    uint elementBytes, rowPitch;
    void* data;
    const(char)* pixelFormat;
    MetaData* metadata;


    // TODO: invariant?

}


// don't call this function in a loop, for the love of god!!
inout(void)[] getPixel(ref inout(ImageBuffer) image, uint x, uint y)
{
    size_t offset = y*image.rowPitch + x*image.elementBytes;
    return image.data[offset .. offset + image.elementBytes];
}


// HACK
inout(char)[] asDString(inout(char)* cstr) @trusted
{
    if (!cstr)
        return null;
    size_t len = 0;
    while (cstr[len])
        ++len;
    return cstr[0 .. len];
}
