module wg.image;

public import wg.image.imagebuffer;
//public import wg.image.rgb;

import wg.image.format;


enum isImage(T) = true; // does T look like an image?
enum isValidPixelType(T) = true; // is T a valid image element type?

/// Typed wrapper over ImageBuffer.
/// It can confirm the formats are matching once at association, and then any further 
/// runtime metadata checks can be handled by the type-checker instead.
struct Image(ElementType)
{
    static assert(isValidPixelType!ElementType, "Image must have a valid element type!");

    alias buffer this; // ???
    ref const(ImageBuffer) buffer() const { return img; }

    this(ref ImageBuffer image)
    {
        assert(image.pixelFormat.asDString[] == formatForPixelType!ElementType[]);
        assert(image.blockWidth == 1 && image.blockHeight == 1 && image.bitsPerBlock / 8 == ElementType.sizeof);
        img = image;
    }

    ElementType[] row(uint y)
    {
        return cast(ElementType[])img.getRow(y);
    }

    ref ElementType at(uint x, uint y)
    {
        return *cast(ElementType*)img.getPixel(x, y).ptr;
    }

package:
    ImageBuffer img = ImageBuffer(0, 0, 0, 1, 1, ElementType.sizeof * 8, 0, null, formatForPixelType!ElementType.ptr, null);

    // internal functions can modify data
    ref ImageBuffer buffer() { return img; }
}


Image!ElementType fromArray(ElementType)(ElementType[] data, uint width, uint height) if (isValidPixelType!ElementType)
{
    assert(data.length == width * height);
    Image!ElementType img;
    img.width = width;
    img.height = height;
    img.rowPitch = img.bitsPerBlock * width / 8;
    img.data = data.ptr;
    img.pixelFormat = formatForPixelType!ElementType.ptr;
    return img;
}
