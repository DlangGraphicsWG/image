// Written in the D programming language.
/**
Image transformations.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.image.transform;

import wg.image;
import wg.image.imagebuffer;
import wg.util.allocator;

///
enum isImageBuffer(T) = is(T == ImageBuffer) || is(T == Image!U, U);

// it's possible to do certain loss-less and opaque transforms on images

///
Image crop(Image)(ref Image image, uint left, uint right, uint top, uint bottom) if (isImageBuffer!Image)
{
    assert(left % image.blockWidth == 0 && right % image.blockHeight == 0 &&
           top % image.blockWidth == 0 && bottom % image.blockHeight == 0);
    assert((image.bitsPerBlock & 7) == 0);
    assert(right >= left && bottom >= top);

    size_t t = top / image.blockHeight;
    size_t l = left / image.blockWidth;

    Image r = image;
    r.data += t*image.rowPitch + l*image.bitsPerBlock / 8;
    r.width = right - left;
    r.height = bottom - top;
    return r;
}

/// strip all metadata from an image buffer
Image stripMetadata(Image)(ref Image image) if (isImageBuffer!Image)
{
    Image r = image;

    // TODO: must find and keep the allocation metadata!
    r.metadata = null;
    return r;
}

// TODO: flip (in-place support?)
// TODO: flip (not in-place, buffer)
// TODO: rotation (requires destination image buffer, with matching format)


///
void copy(SrcImg, DestImg)(auto ref SrcImg src, ref DestImg dest) nothrow @nogc if (isImage!SrcImg)// TODO: if (something about dest...)
{
    // TODO: assert dest is a writable image

    // strongly type the dest buffer if it's soft-typed
    static if (is(DestImg == ImageBuffer))
        auto dst = Image!(ElementType!Src)(dest);
    else
        alias dst = dest;

    assert(src.width == dst.width && src.height == dst.height);

    enum srcByRow = __traits(compiles, src.row(0));
    enum destByRow = __traits(compiles, dst.row(0));

    foreach (y; 0 .. src.height)
    {
        static if (srcByRow && destByRow)
        {
            dst.row(y)[] = src.row(y)[];
        }
        else static if (srcByRow)
        {
            auto srcRow = src.row(y);
            foreach (x; 0 .. src.width)
                dst.at(x, y) = srcRow[x];
        }
        else  static if (destByRow)
        {
            auto destRow = dst.row(y);
            foreach (x; 0 .. src.width)
                destRow[x] = src.at(x, y);
        }
        else
        {
            foreach (x; 0 .. src.width)
                dst.at(x, y) = src.at(x, y);
        }
    }
}

/// Map image elements 
auto map(Img, Fn)(auto ref Img image, auto ref Fn mapFunc)
{
    static struct Map
    {
        alias width = image.width;
        alias height = image.height;

        auto at(uint x, uint y) const pure nothrow @nogc
        {
            return mapFunc(image.at(x, y));
        }

    private:
        Img image;
        Fn mapFunc;
    }

    return Map(image);
}

/// Convert image format
auto convert(TargetFormat, Img)(auto ref Img image) pure nothrow @nogc if (isImage!Img && isValidPixelType!TargetFormat)
{
    import wg.color : convertColor;

    return image.map((ElementType!Img1 e) => e.convertColor!TargetFormat());
}

/// Convert image format
auto convert(TargetFormat)(auto ref ImageBuffer image) if (isValidPixelType!TargetFormat)
{
    import wg.color : convertColor;
    import wg.color.rgb : RGB;
    import wg.color.rgb.colorspace : RGBColorSpace, parseRGBColorSpace;
    import wg.color.rgb.convert : unpackRgbColor;
    import wg.color.rgb.format : RGBFormatDescriptor, parseRGBFormat, makeFormatString;
    import wg.image.format;
    import wg.image.metadata : MetaData;

    // TODO: check if image is already the target format (and use a pass-through path)

    static struct DynamicConv
    {
        alias ConvertFunc = TargetFormat function(const(void)*, ref const(RGBFormatDescriptor) rgbDesc) pure nothrow @nogc;

        this()(auto ref ImageBuffer image)
        {
            this.image = image;

            assert((image.bitsPerBlock & 7) == 0);
            elementBytes = image.bitsPerBlock / 8;

            const(char)[] format = image.format;
            switch(getFormatFamily(format))
            {
                case "rgb":
                    rgbFormat = parseRGBFormat(format);

                    static if (is(TargetFormat == RGB!targetFmt, string targetFmt))
                    {
                        if (rgbFormat.colorSpace[] == TargetFormat.Format.colorSpace[])
                        {
                            // make the unpack format string
                            static if (TargetFormat.Format.colorSpace[] != "sRGB")
                            {
                                // we need to inject the target colourspace into our desired format
                                enum unpackDesc = (RGBFormatDescriptor desc) {
                                    desc.colorSpace = TargetFormat.Format.colorSpace;
                                    return desc;
                                }(parseRGBFormat("rgba_f32_f32_f32_f32"));
                                enum string unpackFormat = makeFormatString(unpackDesc);
                            }
                            else
                                enum string unpackFormat = "rgba_f32_f32_f32_f32";

                            alias UnpackType = RGB!unpackFormat;

                            convFun = (const(void)* e, ref const(RGBFormatDescriptor) desc) {
                                float[4] unpack = unpackRgbColor(e[0 .. desc.bits/8], desc);
                                return UnpackType(unpack[0], unpack[1], unpack[2], unpack[3]).convertColor!TargetFormat();
                            };
                            break;
                        }
                        else
                        {
                            RGBColorSpace cs = parseRGBColorSpace(rgbFormat.colorSpace);

                            if (cs.red   == TargetFormat.ColorSpace.red   &&
                                cs.green == TargetFormat.ColorSpace.green &&
                                cs.blue  == TargetFormat.ColorSpace.blue  &&
                                cs.white == TargetFormat.ColorSpace.white)
                            {
                                // same colourspace, only gamma transformation
                                //convFun = ...
                                assert(false);
                            }
                        }
                    }

                    // unpack to linear
                    // convert to XYZ

                    assert(false);
                    //                    break;
                case "xyz":
                    import wg.color.xyz;
                    if (format == XYZ.stringof)
                        convFun = (const(void)* e, ref const(RGBFormatDescriptor)) => (*cast(const(XYZ)*)e).convertColor!TargetFormat();
                    else if (format == xyY.stringof)
                        convFun = (const(void)* e, ref const(RGBFormatDescriptor)) => (*cast(const(xyY)*)e).convertColor!TargetFormat();
                    else
                        assert(false, "Unknown XYZ format!");
                    break;
                default:
                    assert(false, "TODO: source format not supported: " ~ format);
            }
        }

        @property uint width() const { return image.width; }
        @property uint height() const { return image.height; }

        @property inout(MetaData)* metadata() inout pure nothrow @nogc { return image.metadata; }

        auto at(uint x, uint y) const pure nothrow @nogc
        {
            assert(x < width && y < height);

            size_t offset = y*image.rowPitch + x*elementBytes;
            return convFun(image.data + offset, rgbFormat);
        }

        ImageBuffer image;
        size_t elementBytes;
        ConvertFunc convFun;
        RGBFormatDescriptor rgbFormat;
    }

    return DynamicConv(image);
}

///
enum Placement
{
    right, below
}

/// Join 2 images 
auto join(Placement placement = Placement.right, Img1, Img2)(auto ref Img1 image1, auto ref Img2 image2) pure nothrow @nogc
{
    import wg.util.util : _max;

    static struct Join
    {
        @property uint width() const { return placement == Placement.right ? image1.width + image2.width : _max(image1.width, image2.width); }
        @property uint height() const { return placement == Placement.right ? _max(image1.height, image2.height) : image1.height + image2.height; }

        auto at(uint x, uint y) const pure nothrow @nogc
        {
            assert(x < width && y < height);

            static if (placement == Placement.right)
            {
                if (x < image1.width)
                    return y < image1.height ? image1.at(x, y) : ElementType!Img1();
                else
                    return y < image2.height ? image2.at(x - image1.width, y) : ElementType!Img2();
            }
            else
            {
                if (y < image1.height)
                    return x < image1.width ? image1.at(x, y) : ElementType!Img1();
                else
                    return x < image1.width ? image2.at(x, y - image1.height) : ElementType!Img2();
            }
        }

    private:
        Img1 image1;
        Img2 image2;
    }

    return Join(image1, image2);
}
