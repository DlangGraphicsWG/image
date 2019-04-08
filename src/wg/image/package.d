// Written in the D programming language.
/**
Image definition.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.image;

public import wg.color;
public import wg.image.imagebuffer;

import wg.image.format;
import wg.image.metadata;
import wg.util.allocator;

/// does T look like an image?
enum isImage(T) = true;
/// is T a valid image element type?
enum isValidPixelType(T) = true;

/**
Strong typed wrapper for ImageBuffer.
It will confirm the formats are matching once at construction, and any further
runtime metadata checks can be handled by the type-checker.
*/
struct Image(ElementType)
{
    static assert(isValidPixelType!ElementType, "Image must have a valid element type!");

    alias buffer this; // ???
    ///
    ref inout(ImageBuffer) buffer() inout { return img; }

    ///
    this(ref ImageBuffer image)
    {
        import wg.util.util : asDString;

        assert(image.pixelFormat.asDString[] == FormatForPixelType!ElementType[]);
        assert(image.blockWidth == 1 && image.blockHeight == 1 && image.bitsPerBlock / 8 == ElementType.sizeof);
        img = image;
    }

    ///
    inout(ElementType)[] row(uint y) inout pure nothrow @nogc @trusted
    {
        assert(y < height);
        size_t offset = y*img.rowPitch;
        return cast(ElementType[])img.data[offset .. offset + img.width*ElementType.sizeof];
    }

    ///
    ref inout(ElementType) at(uint x, uint y) inout pure nothrow @nogc @trusted
    {
        assert(x < width && y < height);
        size_t offset = y*img.rowPitch + x*ElementType.sizeof;
        return *cast(inout(ElementType)*)(img.data + offset);
    }

package:
    ImageBuffer img = ImageBuffer(0, 0, 0, 1, 1, ElementType.sizeof * 8, 0, null, FormatForPixelType!ElementType.ptr, null);
}

/**
Create an image buffer from an array of pixel data.
*/
Image!ElementType asImage(ElementType)(ElementType[] data, uint width, uint height) pure nothrow @nogc @safe if (isValidPixelType!ElementType)
{
    assert(data.length == width * height);
    Image!ElementType img;
    img.width = width;
    img.height = height;
    img.rowPitch = img.bitsPerBlock * width / 8;
    img.data = &data[0];
    img.pixelFormat = &FormatForPixelType!ElementType[0];
    return img;
}

// TODO: DMD bug, this must be declared BEFORE the overloads below!!
alias allocImage = wg.image.imagebuffer.allocImage;

/**
Allocate an image of given type in GC memory.
Optionally allocate additional metadata pages.
*/
Image!ElementType allocImage(ElementType = RGBX8, MetadataBlocks...)(uint width, uint height, size_t[] additionalMetadataBytes...)
{
    import std.exception : enforce;

    assert(additionalMetadataBytes.length == MetadataBlocks.length);

    ImageBuffer img;
    void[] mem = allocImageImpl(FormatForPixelType!ElementType, false, width, height, getMetadataSize!(false, MetadataBlocks)(additionalMetadataBytes), getGcAllocator(), img);
    enforce(mem.length > 0, "Failed to allocate image for type: " ~ ElementType.stringof);
    arrangeMetadata!(false, MetadataBlocks)(img.metadata, additionalMetadataBytes);
    return Image!ElementType(img);
}

/**
Allocate an image of given type using the supplied allocator.
Optionally allocate additional metadata pages.
*/
Image!ElementType allocImage(ElementType = RGBX8, MetadataBlocks...)(uint width, uint height, Allocator* allocator, size_t[] additionalMetadataBytes...) nothrow @nogc
{
    assert(additionalMetadataBytes.length == MetadataBlocks.length);

    ImageBuffer img;
    void[] mem = allocImageImpl(FormatForPixelType!ElementType, false, width, height, getMetadataSize!(true, MetadataBlocks)(additionalMetadataBytes), allocator, img);
    if (mem.length)
    {
        AllocationMetadata* allocData = arrangeMetadata!(true, MetadataBlocks)(img.metadata, additionalMetadataBytes);
        allocData.allocations[0].allocator = allocator;
        allocData.allocations[0].mem = mem;
    }
    return Image!ElementType(img);
}
