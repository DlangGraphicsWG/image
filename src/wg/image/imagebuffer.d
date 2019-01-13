module wg.image.imagebuffer;

import wg.image;
import wg.image.metadata;

struct ImageBuffer
{
    uint width, height;
    uint rowPitch;
    ubyte blockWidth = 1, blockHeight = 1;
    ubyte bitsPerBlock;
    ubyte reserved;
    void* data;
    const(char)* pixelFormat;
    MetaData* metadata;

    // 40 bytes so far...
    // I'd prefer it was 32, but I'm not sure benefit is worth complexity
    // We could put the format in metadata...?
    // ...but that would necessitate that common metadata is *always* present, even for the simplest images, which is a bit disappointing.

    // TODO: invariant?

}


inout(void)[] getRow(ref inout(ImageBuffer) image, uint y)
{
    size_t offset = y*image.rowPitch;
    return image.data[offset .. offset + image.width*image.bitsPerBlock/8];
}

// don't call this function in a loop, for the love of god!!
inout(void)[] getPixel(ref inout(ImageBuffer) image, uint x, uint y)
{
    debug assert((image.bitsPerBlock & 7) == 0);
    size_t elementBytes = image.bitsPerBlock / 8;
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
