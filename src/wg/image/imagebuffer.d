module wg.image.imagebuffer;

import wg.image;
import wg.image.metadata;
import wg.util.allocator;

/**
 * Struct to hold a buffer of image data.
 */
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


/**
 * Allocate an image buffer for the specified format in GC memory.
 * Optionally allocate additional metadata pages.
 */
ImageBuffer allocImage(MetadataBlocks...)(const(char)[] format, uint width, uint height, size_t[] additionalMetadataBytes...)
{
    import std.exception : enforce;

    assert(additionalMetadataBytes.length == MetadataBlocks.length);

    ImageBuffer img;
    void[] mem = allocImageImpl(format, true, width, height, getMetadataSize!(false, MetadataBlocks)(additionalMetadataBytes), getGcAllocator(), img);
    enforce(mem.length > 0, "Failed to allocate image with format: " ~ format);
    arrangeMetadata!(false, MetadataBlocks)(img.metadata, additionalMetadataBytes);
    return img;
}

/**
 * Allocate an image buffer for the specified format using the supplied allocator.
 * Optionally allocate additional metadata pages.
 */
ImageBuffer allocImage(MetadataBlocks...)(const(char)[] format, uint width, uint height, Allocator* allocator, size_t[] additionalMetadataBytes...) nothrow @nogc
{
    assert(additionalMetadataBytes.length == MetadataBlocks.length);

    ImageBuffer img;
    void[] mem = allocImageImpl(format, true, width, height, getMetadataSize!(true, MetadataBlocks)(additionalMetadataBytes), allocator, img);
    if (mem.length)
    {
        AllocationMetadata* allocData = arrangeMetadata!(true, MetadataBlocks)(img.metadata, additionalMetadataBytes);
        allocData.allocations[0].allocator = allocator;
        allocData.allocations[0].mem = mem;
    }
    return img;
}

/**
 * Free any allocations contained in an image buffer.
 */
void freeImage(ref ImageBuffer image) nothrow @nogc
{
    AllocationMetadata* allocData = image.getMetadata!AllocationMetadata();
    if (allocData)
    {
        // cache the allocation pages locally, since we will probably delete them along the way
        AllocationMetadata.Page[128] allocations;
        allocations[0 .. allocData.allocations.length] = allocData.allocations[];

        // delete all associated allocations
        foreach (ref page; allocations[0 .. allocData.allocations.length])
        {
            if (page.allocator)
                page.allocator.deallocate(page.mem);
        }
    }

    image.data = null;
    image.pixelFormat = null;
    image.metadata = null;
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
inout(char)[] asDString(inout(char)* cstr) pure nothrow @nogc @trusted
{
    if (!cstr)
        return null;
    size_t len = 0;
    while (cstr[len])
        ++len;
    return cstr[0 .. len];
}


package:

size_t getMetadataSize(bool includeAlloc, MetadataBlocks...)(size_t[] additionalMetadataBytes...) nothrow @nogc
{
    size_t additionalBytes = 0;
    static foreach (i; 0 .. MetadataBlocks.length)
        additionalBytes += MetaData.sizeof + MetadataBlocks[i].sizeof + ((additionalMetadataBytes[i] + 7) & ~7);
    static if (includeAlloc)
        additionalBytes += MetaData.sizeof + AllocationMetadata.sizeof + AllocationMetadata.Page.sizeof*4;
    return additionalBytes;
}

AllocationMetadata* arrangeMetadata(bool includeAlloc, MetadataBlocks...)(MetaData* metadata, size_t[] additionalMetadataBytes...) nothrow @nogc
{
    // lay out the metadata...
    static foreach (i; 0 .. MetadataBlocks.length)
    {
        metadata.magic = MetadataBlocks[i].ID;
        metadata.bytes = cast(uint)(MetadataBlocks[i].sizeof + additionalMetadataBytes[i]);
        static if (includeAlloc || i < MetadataBlocks.length - 1)
            metadata.next = cast(MetaData*)(cast(void*)metadata + MetaData.sizeof + MetadataBlocks[i].sizeof + ((additionalMetadataBytes[i] + 7) & ~7));
        else
            metadata.next = null;
        *metadata.data!(MetadataBlocks[i])() = MetadataBlocks[i]();
        metadata = metadata.next;
    }
    static if (includeAlloc)
    {
        metadata.magic = AllocationMetadata.ID;
        metadata.bytes = AllocationMetadata.sizeof + AllocationMetadata.Page.sizeof*4;
        metadata.next = null;

        AllocationMetadata* allocData = metadata.data!AllocationMetadata();
        allocData.allocations = (cast(AllocationMetadata.Page*)(allocData + 1))[0 .. 4];
        allocData.allocations[0 .. 4] = AllocationMetadata.Page();
        return allocData;
    }
    else
        return null;
}

void[] allocImageImpl(const(char)[] format, bool copyFormat, uint width, uint height, size_t metadataBytes, Allocator* allocator, out ImageBuffer image) nothrow @nogc
{
    import wg.image.format : getImageParams;

    if (!getImageParams(format, width, height, image))
        return null;

    size_t imageSize = image.rowPitch * height;

    void[] mem = allocator.allocate(imageSize + metadataBytes + (copyFormat ? format.length + 1 : 0));

    image.data = mem.ptr;
    image.metadata = metadataBytes ? cast(MetaData*)(image.data + imageSize) : null;

    if (copyFormat)
    {
        char* fmtCopy = cast(char*)image.data + imageSize + metadataBytes;
        fmtCopy[0 .. format.length] = format[];
        fmtCopy[format.length] = '\0';
        image.pixelFormat = fmtCopy;
    }
    else
        image.pixelFormat = format.ptr;

    return mem;
}
