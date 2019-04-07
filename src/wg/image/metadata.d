// Written in the D programming language.
/**
Metadata that is associated with an image buffer.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.image.metadata;

import wg.image.imagebuffer;
import wg.util.allocator;

/**
Image metadata header structure.
*/
struct MetaData
{
    ///
    char[4] magic;
    ///
    uint bytes;
    ///
    MetaData* next;

    ///
    @property inout(void)[] data() inout return @trusted pure nothrow @nogc
    {
        // null? ie, bytes == 0? yes
        return (cast(inout(void)*)&this)[typeof(this).sizeof .. typeof(this).sizeof + bytes];
    }

    ///
    @property inout(MDType)* data(MDType)() inout return @trusted pure nothrow @nogc
    {
        assert(magic == MDType.ID && bytes >= MDType.sizeof);
        return cast(inout(MDType)*)(data().ptr);
    }
}


/**
Find metadata structure in image by id.
*/
inout(void)[] getMetadata(ref inout(ImageBuffer) image, const(char)[4] id) @safe pure nothrow @nogc
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

/**
Find metadata in image by type.
*/
inout(MDType)* getMetadata(MDType)(ref inout(ImageBuffer) image) @trusted pure nothrow @nogc
{
    inout(void)[] md = image.getMetadata(MDType.ID);
    if (!md)
        return null;
    assert(md.length >= MDType.sizeof); // shouldn't assert for this
    return cast(inout(MDType)*)md.ptr;
}

/**
Find or create metadata structure in an image buffer by type.
If the metadata exists but is smaller than requested `additionalBytes`, it is re-allocated.
*/
MDType* getOrInsertMetadata(MDType)(ref ImageBuffer image, size_t additionalBytes = 0)
{
    void[] md = image.getMetadata(MDType.ID);
    if (md && md.length >= MDType.sizeof + additionalBytes)
        return cast(MDType*)md.ptr;
    return image.insertMetadata!MDType(additionalBytes);
}

/**
Find or create metadata structure in an image buffer by type.
If the metadata exists but is smaller than requested `additionalBytes`, it is re-allocated.
*/
MDType* getOrInsertMetadata(MDType)(ref ImageBuffer image, Allocator* allocator, size_t additionalBytes = 0) nothrow @nogc
{
    void[] md = image.getMetadata(MDType.ID);
    if (md && md.length >= MDType.sizeof + additionalBytes)
        return cast(MDType*)md.ptr;
    return image.insertMetadata!MDType(allocator, additionalBytes);
}

/**
Insert new metadata structure into an image buffer by type.
If the metadata struct is already present, it is re-allocated.
*/
MDType* insertMetadata(MDType)(ref ImageBuffer image, size_t additionalBytes = 0)
{
    MetaData* md = cast(MetaData*)(new void[getMetadataSize!(false, MDType)(additionalBytes)]).ptr;
    arrangeMetadata!(false, MDType)(md, additionalBytes);
    md.next = image.metadata;
    image.metadata = md;
    return md.data!MDType;
}

/**
Insert new metadata structure into an image buffer by type.
If the metadata struct is already present, it is re-allocated.
*/
MDType* insertMetadata(MDType)(ref ImageBuffer image, Allocator* allocator, size_t additionalBytes = 0) nothrow @nogc
{
    AllocationMetadata* allocData = image.getMetadata!AllocationMetadata();
    MetaData* md;
    if (!allocData)
    {
        // we need to allocate a new AllocationMetadata
        size_t allocLen = getMetadataSize!(true, MDType)(additionalBytes);
        void[] mem = allocator.allocate(allocLen);
        md = cast(MetaData*)mem.ptr;
        allocData = arrangeMetadata!(true, MDType)(md, additionalBytes);
        allocData.allocations[0].allocator = allocator;
        allocData.allocations[0].mem = mem;
        md.next.next = image.metadata;
    }
    else
    {
        // AllocationMetadata already exists, but maybe it's full?
        bool extendAllocTable = allocData.isFull();
        size_t allocTableBytes = extendAllocTable ? AllocationMetadata.Page.sizeof*allocData.allocations.length*2 : 0;
        size_t allocLen = getMetadataSize!(false, MDType)(additionalBytes + allocTableBytes);
        void[] mem = allocator.allocate(allocLen);
        md = cast(MetaData*)mem.ptr;
        arrangeMetadata!(false, MDType)(md, additionalBytes);
        md.next = image.metadata;
        if (extendAllocTable)
        {
            // AllocationMetadata is full, so we'll extend the table at the tail of this new allocation
            AllocationMetadata.Page[] newPages = cast(AllocationMetadata.Page[])mem[$ - allocTableBytes .. $];
            newPages[0 .. allocData.allocations.length] = allocData.allocations[];
            newPages[allocData.allocations.length].allocator = allocator;
            newPages[allocData.allocations.length].mem = mem;
            newPages[allocData.allocations.length + 1 .. $] = AllocationMetadata.Page();
            allocData.allocations = newPages;
        }
        else
        {
            // add new allocation to the allocation table
            foreach (ref a; allocData.allocations)
            {
                if (a.allocator == null)
                {
                    a.allocator = allocator;
                    a.mem = mem;
                    break;
                }
            }
        }
    }
    image.metadata = md;
    return md.data!MDType;
}


/**
Common metadata struct.
*/
struct CommonMetadata
{
    ///
    enum char[4] ID = "META";

    /// defined as w/h; animorphic images > 1.0
    float pixelAspect = 1.0f;
    /// image has no associated physical units
    float horizDpi = 0;

    ///
    float[2] getDPI() const @safe pure nothrow @nogc { return [ horizDpi, horizDpi / pixelAspect ]; }
}

/**
Get the pixel aspect ratio for an image.
*/
float getPixelAspect(ref const(ImageBuffer) image) @safe pure nothrow @nogc
{
    auto md = image.getMetadata!CommonMetadata();
    return md ? md.pixelAspect : 1.0f;
}

/**
Get the display aspect ratio for an image.
*/
float getAspectRatio(ref const(ImageBuffer) image) @safe pure nothrow @nogc
{
    return cast(float)image.width / cast(float)image.height * image.getPixelAspect();
}


/**
Allocation metadata struct.
Store ownership of allocations which can be used to clean-up allocated data.
*/
struct AllocationMetadata
{
    import wg.util.allocator;

    ///
    enum char[4] ID = "ALOC";

    ///
    struct Page
    {
        ///
        Allocator* allocator;
        ///
        void[] mem;
    }

    ///
    Page[] allocations;

    private bool isFull() const pure nothrow @nogc @safe
    {
        return allocations[$-1].allocator != null;
    }
}
