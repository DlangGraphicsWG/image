module wg.image.metadata;

import wg.image.imagebuffer;

// metadata header struct

struct MetaData
{
    char[4] magic;
    uint bytes;
    MetaData* next;

    @property inout(void)[] data() inout return
    {
        // null? ie, bytes == 0? yes
        return (cast(inout(void)*)&this)[typeof(this).sizeof .. typeof(this).sizeof + bytes];
    }
}

inout(void)[] getMetadata(ref inout(ImageBuffer) image, const(char)[4] id)
{
    inout(MetaData)* md = image.metadata;
    while (md)
    {
        if (md.magic == id)
            return md.data;
        md = md.next;
    }
    return null;
}

inout(MDType)* getMetadataAs(MDType)(ref inout(ImageBuffer) image)
{
    inout(void)[] md = image.getMetadata(MDType.ID);
    if (!md)
        return null;
    assert(md.length >= MDType.sizeof); // shouldn't assert for this
    return cast(inout(MDType)*)md.ptr;
}


// common metadata block for common but still somewhat niche data

struct CommonMetadata
{
    enum char[4] ID = "META";

    float pixelAspect = 1.0f;
    short[2] dpi = [ 96, 96 ];
}

float getPixelAspect(ref const(ImageBuffer) image)
{
    auto md = image.getMetadataAs!CommonMetadata();
    return md ? md.pixelAspect : 1.0f;
}

float getAspectRatio(ref const(ImageBuffer) image)
{
    return cast(float)image.width / cast(float)image.height * image.getPixelAspect();
}

