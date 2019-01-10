module wg.image.imagebuffer;

import wg.image;
import wg.image.metadata;

struct ImageBuffer
{
    uint width, height;
    uint elementBits, rowPitch;
    void* data;
    const(char)* pixelFormat;
    MetaData* metadata;


    // TODO: invariant?

}


inout(void)[] getRow(ref inout(ImageBuffer) image, uint y)
{
    size_t offset = y*image.rowPitch;
    return image.data[offset .. offset + image.width*image.elementBits/8];
}

// don't call this function in a loop, for the love of god!!
inout(void)[] getPixel(ref inout(ImageBuffer) image, uint x, uint y)
{
    debug assert((image.elementBits & 7) == 0);
    size_t elementBytes = image.elementBits / 8;
    size_t offset = y*image.rowPitch + x*elementBytes;
    return image.data[offset .. offset + elementBytes];
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
