// Written in the D programming language.
/**
Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.image.imagebuffer;

import wg.image;
import wg.image.metadata;
import wg.util.allocator;

/**
Struct to hold a buffer of image data.
*/
struct ImageBuffer
{
    /// Image width in pixels
    uint width;
    /// Image height in pixels
    uint height;
    /// Row pitch in bytes
    uint rowPitch;

    /// Block width (1 for plain pixel maps)
    ubyte blockWidth = 1;
    /// Block height (1 for plain pixel maps)
    ubyte blockHeight = 1;
    /// Bits per block
    ubyte bitsPerBlock;
    /// Reserved for future use.
    ubyte reserved;

    /// Pointer to image buffer
    void* data;

    /// Null-terminated format string
    const(char)* pixelFormat;

    /// Linked list of metadata pages
    MetaData* metadata;

    /// Get the format string
    @property const(char)[] format() const pure nothrow @nogc @safe
    {
        import wg.util.util : asDString;
        return pixelFormat.asDString();
    }

    /// Get the image buffer as an array
    @property inout(void)[] imageBuffer() inout pure nothrow @nogc
    {
        return data[0 .. height * rowPitch];
    }

    // 40 bytes so far...
    // I'd prefer it was 32, but I'm not sure benefit is worth complexity
    // We could put the format in metadata...?
    // ...but that would necessitate that common metadata is *always* present, even for the simplest images, which is a bit disappointing.

    // TODO: invariant?
}


/**
Allocate an image buffer for the specified format in GC memory.
Optionally allocate additional metadata pages.
*/
ImageBuffer allocImage(MetadataBlocks...)(const(char)[] format, uint width, uint height, size_t[] additionalMetadataBytes...)
{
    import std.exception : enforce;

    assert(additionalMetadataBytes.length == MetadataBlocks.length);

    ImageBuffer img;
    mem = allocImageImpl(format, true, width, height, getMetadataSize!(false, MetadataBlocks)(additionalMetadataBytes), getGcAllocator(), img);
    enforce(img.data != null, "Failed to allocate image with format: " ~ format);
    arrangeMetadata!(false, MetadataBlocks)(img.metadata, additionalMetadataBytes);
    return img;
}

/**
Allocate an image buffer for the specified format using the supplied allocator.
Optionally allocate additional metadata pages.
*/
ImageBuffer allocImage(MetadataBlocks...)(const(char)[] format, uint width, uint height, Allocator* allocator, size_t[] additionalMetadataBytes...) nothrow @nogc
{
    assert(additionalMetadataBytes.length == MetadataBlocks.length);

    ImageBuffer img;
    void[] mem = allocImageImpl(format, true, width, height, getMetadataSize!(true, MetadataBlocks)(additionalMetadataBytes), allocator, img);
    if (img.data == null)
    {
        // allocation failed! what should we do?
        return Image!ElementType();
    }
    AllocationMetadata* allocData = arrangeMetadata!(true, MetadataBlocks)(img.metadata, additionalMetadataBytes);
    allocData.allocations[0].allocator = allocator;
    allocData.allocations[0].mem = img.imageBuffer[];
    allocData.allocations[1].allocator = allocator;
    allocData.allocations[1].mem = mem;
    return img;
}

/**
Free any allocations contained in an image buffer.
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

///
ImageBuffer clone(ref ImageBuffer image)
{
    // GC clone allocates the image buffer, strings, and each metadata page separately
    // ...is that what we want?
    ImageBuffer r = image;
    r.data = &image.imageBuffer.dup()[0];
    r.metadata = cast(MetaData*)cloneMetadata(image.metadata, false, 0, getGcAllocator()).ptr;
    r.pixelFormat = &image.pixelFormat[0 .. image.format.length + 1].dup()[0]; // must include the null-terminator
    return r;
}

///
ImageBuffer clone(ref ImageBuffer image, Allocator* allocator) nothrow @nogc
{
    ImageBuffer r = image;

    // copy image
    void[] data = allocator.allocate(image.imageBuffer.length);
    data[] = image.imageBuffer[];
    r.data = data.ptr;

    // copy metadata
    size_t formatLen = image.format.length + 1;
    void[] metadata = cloneMetadata(image.metadata, true, formatLen, allocator);
    r.metadata = cast(MetaData*)metadata.ptr;

    // add image data to allocation metadata
    AllocationMetadata* allocData = r.getMetadata!AllocationMetadata();
    allocData.allocations[1].allocator = allocator;
    allocData.allocations[1].mem = data;

    // copy format string
    char* fmt = cast(char*)&metadata[$ - formatLen];
    fmt[0 .. formatLen] = image.pixelFormat[0 .. formatLen];
    r.pixelFormat = fmt;

    return r;
}

///
inout(void)[] getRow(ref inout(ImageBuffer) image, uint y)
{
    size_t offset = y*image.rowPitch;
    return image.data[offset .. offset + image.width*image.bitsPerBlock/8];
}

/// don't call this function in a loop, for the love of god!!
inout(void)[] getPixel(ref inout(ImageBuffer) image, uint x, uint y)
{
    debug assert((image.bitsPerBlock & 7) == 0);
    size_t elementBytes = image.bitsPerBlock / 8;
    size_t offset = y*image.rowPitch + x*elementBytes;
    return image.data[offset .. offset + elementBytes];
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

size_t countMetadataBytes(const(MetaData)* metadata) pure nothrow @nogc
{
    size_t mdSize = 0;
    outer: for (const(MetaData)* md = metadata; md; md = md.next)
    {
        // skip "ALOC" from source
        if (md.magic[] == AllocationMetadata.ID)
            continue;
        // check if `md` is a duplicate
        for (const(MetaData)* md2 = metadata; md2 != md; md2 = md2.next)
        {
            if (md2.magic == md.magic)
                continue outer;
        }
        // not a duplicate, count the bytes
        mdSize += MetaData.sizeof + md.bytes;
    }
    return mdSize;
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

void[] cloneMetadata(const(MetaData)* src, bool includeAlloc, size_t extraBytes, Allocator* allocator) nothrow @nogc
{
    size_t mdSize = countMetadataBytes(src) + extraBytes;

    enum NumAllocPages = 4;
    if (includeAlloc)
        mdSize += MetaData.sizeof + AllocationMetadata.sizeof + AllocationMetadata.Page.sizeof * NumAllocPages;

    if (mdSize == 0)
        return null;

    void[] mdAlloc = allocator.allocate(mdSize);

    // clone metadata blocks
    MetaData* mdCopy = cast(MetaData*)mdAlloc.ptr;
    MetaData* prev = null;
    outer: for (const(MetaData)* md = src; md; md = md.next)
    {
        // skip "ALOC" from source
        if (md.magic[] == AllocationMetadata.ID)
            continue;
        // check if `md` is a duplicate
        for (const(MetaData)* md2 = src; md2 != md; md2 = md2.next)
        {
            if (md2.magic == md.magic)
                continue outer;
        }

        // copy this one
        mdCopy.magic = md.magic;
        mdCopy.bytes = md.bytes;
        mdCopy.data[] = md.data[];
        mdCopy.next = null;
        if (prev)
            prev.next = mdCopy;
        prev = mdCopy;

        mdCopy = cast(MetaData*)(cast(void*)mdCopy + MetaData.sizeof + md.bytes);
    }

    if (includeAlloc)
    {
        mdCopy.magic = AllocationMetadata.ID;
        mdCopy.bytes = AllocationMetadata.sizeof + AllocationMetadata.Page.sizeof * NumAllocPages;
        mdCopy.next = null;
        if (prev)
            prev.next = mdCopy;
        prev = mdCopy;

        AllocationMetadata* alloc = mdCopy.data!AllocationMetadata();
        alloc.allocations = (cast(AllocationMetadata.Page*)(alloc + 1))[0 .. NumAllocPages];
        alloc.allocations[0].allocator = allocator;
        alloc.allocations[0].mem = mdAlloc;
        alloc.allocations[1 .. $] = AllocationMetadata.Page();
    }

    return mdAlloc;
}

void[] allocImageImpl(const(char)[] format, bool copyFormat, uint width, uint height, size_t metadataBytes, Allocator* allocator, out ImageBuffer image) nothrow @nogc
{
    import wg.image.format : getImageParams;

    if (!getImageParams(format, width, height, image))
        return null;

    void[] imageData = allocator.allocate(image.rowPitch * height);
    image.data = imageData.ptr;

    if (!copyFormat)
        image.pixelFormat = format.ptr;

    if (metadataBytes == 0 && !copyFormat)
        return null;

    void[] metadata = allocator.allocate(metadataBytes + (copyFormat ? format.length + 1 : 0));
    image.metadata = metadataBytes ? cast(MetaData*)metadata.ptr : null;

    if (copyFormat)
    {
        char* fmt = cast(char*)metadata.ptr + metadataBytes;
        fmt[0 .. format.length] = format[];
        fmt[format.length] = '\0';
        image.pixelFormat = fmt;
    }

    return metadata;
}
