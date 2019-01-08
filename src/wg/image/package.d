module wg.image;

public import wg.image.imagebuffer;
//public import wg.image.rgb;

import wg.image.format;


enum isImage(T) = true; // does T look like an image?
enum isValidPixelType(T) = true; // is T a valid image element type?

struct Image(ElementType)
{
    static assert(isValidPixelType!ElementType, "Image must have a valid element type!");

    alias buffer this; // ???
    ref const(ImageBuffer) buffer() const { return img; }

    this(ref ImageBuffer image)
    {
        assert(image.pixelFormat.asDString == formatForPixelType!ElementType);
        assert(image.elementBytes == ElementType.sizeof);
        img = image;
    }

    ref ElementType at(uint x, uint y)
    {
        return *cast(ElementType*)img.getPixel(x, y).ptr;
    }

package:
    ImageBuffer img = ImageBuffer(0, 0, ElementType.sizeof, 0, null, formatForPixelType!ElementType, null);

    // internal functions can modify data
    ref ImageBuffer buffer() { return img; }
}


Image!ElementType fromArray(ElementType)(ElementType[] data, uint width, uint height) if (isValidPixelType!ElementType)
{
    assert(data.length == width * height);
    Image!ElementType img;
    img.width = width;
    img.height = height;
    img.rowPitch = img.elementBytes * width;
    img.data = data.ptr;
    img.pixelFormat = formatForPixelType!ElementType.ptr;
    return img;
}
