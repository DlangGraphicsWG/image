// Written in the D programming language.
/**
A very basic BMP file format reader/writer.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.format.bmp;

import wg.image;
import wg.image.metadata;
import wg.image.transform;
import wg.util.allocator;
import wg.util.parse : parseReal;

/**
Create an ImageBuffer from a BMP formatted image.
*/
ImageBuffer readBMP(void[] bmpBuffer)
{
    auto bmp = BMPImage(bmpBuffer);
    ImageBuffer src = bmp.getImage();
    return src.clone();
}

/**
Create an ImageBuffer from a BMP formatted image.
*/
ImageBuffer readBMP(void[] bmpBuffer, Allocator* allocator) //nothrow @nogc
{
    auto bmp = BMPImage(bmpBuffer);
    ImageBuffer src = bmp.getImage();
    return src.clone(allocator);
}

/**
Create an ImageBuffer from a BMP formatted image.
*/
Image!RuntimeFormat readBMP(RuntimeFormat)(void[] bmpBuffer)
{
    auto bmp = BMPImage(bmpBuffer);
    ImageBuffer src = bmp.getImage();
    return src.convert!(RuntimeFormat).clone();
}

/**
Create an ImageBuffer from a BMP formatted image.
*/
Image!RuntimeFormat readBMP(RuntimeFormat)(void[] bmpBuffer, Allocator* allocator) //nothrow @nogc
{
    auto bmp = BMPImage(bmpBuffer);
    ImageBuffer src = bmp.getImage();
    return src.convert!(RuntimeFormat).clone(allocator);
}

/**
Format an image into a BMP image buffer.
*/
void[] writeBMP(ref const(ImageBuffer) image)
{
    return writeBMP(image, getGcAllocator());
}

/**
Format an image into a BMP image buffer.
*/
void[] writeBMP(ref const(ImageBuffer) image, Allocator* allocator) nothrow @nogc
{
    import wg.color.rgb.format : RGBFormatDescriptor, parseRGBFormat;
    import wg.util.util : asDString;

    if (image.blockWidth != 1 || image.blockHeight != 1 ||
        (image.bitsPerBlock != 16 && image.bitsPerBlock != 24 && image.bitsPerBlock != 32))
    {
        // we need to transcode this image...
        return null;
    }

    // we appear to have a valid image...
    RGBFormatDescriptor* format = parseRGBFormat(image.pixelFormat.asDString, allocator);
    scope(exit) allocator.deallocate(format);

    // determine the components are formatted okay
    uint red, green, blue, alpha;
    uint bit = 0;
    foreach (ref component; format.components) with (RGBFormatDescriptor)
    {
        // need to transcode the image!
        if (component.format != Format.NormInt)
            return null;

        switch (component.type)
        {
            case Component.Red:     red     = ((1 << component.bits) - 1) << bit; break;
            case Component.Green:   green   = ((1 << component.bits) - 1) << bit; break;
            case Component.Blue:    blue    = ((1 << component.bits) - 1) << bit; break;
            case Component.Alpha:   alpha   = ((1 << component.bits) - 1) << bit; break;
            case Component.Unused:  break;
            default:
                // need to transcode the image!
                return null;
        }
        bit += component.bits;
    }

    uint bytesPerPixel = image.bitsPerBlock / 8;
    uint bmpPitch = (image.width*bytesPerPixel + 3) & ~3;

    uint headerSize = BMPFileHeader.sizeof + BMPInfo!4.sizeof;
    uint imageSize = bmpPitch * image.height;
    uint fileSize = headerSize + imageSize;

    void[] bmp = allocator.allocate(fileSize);

    BMPFileHeader* header = cast(BMPFileHeader*)bmp.ptr;
    BMPInfo!4* info = cast(BMPInfo!4*)(header + 1);
    void* data = cast(void*)(info + 1);

    *header = BMPFileHeader.init;
    header.size = cast(uint)fileSize;
    header.offBits = cast(uint)headerSize;

    *info = BMPInfo!4.init;
    info.size = BMPInfo!4.sizeof;
    info.width = image.width;
    info.height = -cast(int)image.height;
    info.bitCount = image.bitsPerBlock;
    info.compression = Compression.BI_BITFIELDS;
    info.sizeImage = imageSize;
    info.redMask = red;
    info.greenMask = green;
    info.blueMask = blue;
    info.alphaMask = alpha;

    const(CommonMetadata)* md = image.getMetadata!CommonMetadata();
    if (md)
    {
        float[2] dpi = md.getDPI();
        info.xPelsPerMeter = cast(int)(dpi[0] * 39.37007874);
        info.yPelsPerMeter = cast(int)(dpi[1] * 39.37007874);
    }

    if (format.colorSpace.length >= 4 && format.colorSpace[0 .. 4] == "sRGB")
        info.csType = LogicalColorSpace.LCS_sRGB;
    else
        info.csType = LogicalColorSpace.LCS_WINDOWS_COLOR_SPACE;
    // TODO: convert xyY to XYZ...
//    else
//        info.csType = LogicalColorSpace.LCS_CALIBRATED_RGB;

    if (format.colorSpace != "sRGB")
    {
        import wg.color.rgb.colorspace;

        // decode color space
        RGBColorSpace* cs = parseRGBColorSpace(format.colorSpace, allocator);
        scope(exit) allocator.deallocate(cs);

        // specify gamma
        float gamma;
        if (cs.gamma.parseReal(gamma) > 0)
        {
            info.gammaRed = FP16Dot16(cast(uint)(gamma * 0x10000));
            info.gammaGreen = info.gammaRed;
            info.gammaBlue = info.gammaRed;
        }

        // TODO: convert xyY to XYZ...
        // specify primaries
//        info.endpoints.red = ;
//        info.endpoints.green = ;
//        info.endpoints.blue = ;
    }

    // write image data
    const(void)* src = image.data;
    uint rowBytes = bytesPerPixel * image.width;
    foreach (h; 0 .. image.height)
    {
        data[0 .. rowBytes] = src[0 .. rowBytes];
        src += image.rowPitch;
        data += bmpPitch;
    }

    return bmp;
}


private:

///
struct BMPImage
{
    void[] data;

    ///
    this(void[] image)
    {
        data = image;

        // check we actually have a BMP image
        if (*cast(ushort*)&data[0] == 0)
        {
            const(BMPInfoV1)* info = infoHeader!BMPInfoV1();
            assert(info.planes == 1);
            assert(info.bitsPerPixel >= 1 && info.bitsPerPixel <= 8);
        }
        else
        {
            BMPFileHeader* h = header();
            assert(h.type[] == "BM");
            assert(h.size == data.length);
            assert(bmpVersion() != 0);
        }
    }

    ///
    BMPFileHeader* header() const
    {
        return cast(BMPFileHeader*)&data[0];
    }

    ///
    int bmpVersion(const(ubyte)** palette = null) const
    {
        if (*cast(ushort*)&data[0] == 0)
            return 1;
        const(ubyte)* info = cast(const(ubyte)*)(header() + 1);
        uint size = *cast(const(uint)*)info;
        switch (size)
        {
            case BMPInfo!2.sizeof:
                if (palette) *palette = info + BMPInfo!2.sizeof;
                return 2;
            case BMPInfo!3.sizeof:
                if (palette) *palette = info + BMPInfo!3.sizeof;
                return 3;
            case BMPInfo!4.sizeof:
                if (palette) *palette = info + BMPInfo!4.sizeof;
                return 4;
            case BMPInfo!5.sizeof:
                if (palette) *palette = info + BMPInfo!5.sizeof;
                return 5;
            default:
                return 0;
        }
    }

    ///
    const(Info)* infoHeader(Info)() const
    {
        static if (is(Info == BMPInfoV1))
            return cast(const(Info)*)&data[0];
        else
            return cast(const(Info)*)(header() + 1);
    }

    ///
    const(void)[] iccData() const
    {
        if (bmpVersion() < 5)
            return null;
        const(BMPInfo!5)* info = infoHeader!(BMPInfo!5)();
        return (cast(void*)info + info.profileData)[0 .. info.profileSize];
    }

    ///
    inout(ImageBuffer) getImage() inout
    {
        import wg.util.format : formatInt, formatReal;

        ImageBuffer img;
        CommonMetadata md;

        string cs = "sRGB";
        string format;
        uint width, height;
        uint pitch;
        ubyte bits;
        Compression compression = Compression.BI_RGB;
        int paletteLength = 0;
        bool topDown = false;

        // TODO: no paletted images...

        const(ubyte)* paletteData;
        int bmpVer = bmpVersion(&paletteData);
        final switch(bmpVer)
        {
            case 1:
                const(BMPInfoV1)* info = infoHeader!BMPInfoV1();
                bits = info.bitsPerPixel;
                width = info.width;
                height = info.height;
                pitch = info.byteWidth;

                // colors are always CLUT from a fixed win1.0 palette
                assert(false);
            case 2:
                const(BMPInfo!2)* info = infoHeader!(BMPInfo!2)();

                assert(info.planes == 1 && info.bitCount < 256);
                bits = cast(ubyte)info.bitCount;

                width = info.width;
                height = info.height;

                pitch = (((bits * width) / 8) + 3) & ~3;
                break;
            case 5:
                const(BMPInfo!5)* info = infoHeader!(BMPInfo!5)();

                // what is 'intent'?

                goto case 4;
            case 4:
                const(BMPInfo!4)* info = infoHeader!(BMPInfo!4)();

                // check csType...
                switch (info.csType)
                {
                    case LogicalColorSpace.LCS_CALIBRATED_RGB:
                        if (info.gammaGreen != info.gammaRed || info.gammaGreen != info.gammaBlue)
                        {
                            // TODO: what if gamma's are different?
                            // should transform red and blue to match green gamma...
                            assert(0);
                        }
                        float gamma = info.gammaGreen / float(0x10000);
                        cs ~= '^' ~ gamma.formatReal(2);

                        // TODO: parse the primaries!!
                        break;
                    case LogicalColorSpace.PROFILE_LINKED:
                        const(char)[] icc = cast(const(char)[])iccData();
                        // TODO: what to do with this icc filename??
                        break;
                    case LogicalColorSpace.PROFILE_EMBEDDED:
                        const(void)[] icc = iccData();
                        // TODO: what to do with this data block??
                        break;
                    case LogicalColorSpace.LCS_sRGB:
                    case LogicalColorSpace.LCS_WINDOWS_COLOR_SPACE:
                        break;
                    default:
                        assert(0);
                }

                goto case 3;
            case 3:
                const(BMPInfo!3)* info = infoHeader!(BMPInfo!3)();

                assert(info.planes == 1 && info.bitCount < 256);
                bits = cast(ubyte)info.bitCount;

                assert(info.width >= 0);
                width = info.width;

                if (info.height < 0)
                {
                    topDown = true;
                    height = -info.height;
                }
                else
                    height = info.height;

                pitch = (((bits * width) / 8) + 3) & ~3;

                paletteLength = info.clrUsed;

                switch (info.compression)
                {
                    case Compression.BI_RLE8:
                    case Compression.BI_RLE4:
                    case Compression.BI_JPEG:
                    case Compression.BI_PNG:
                    case Compression.BI_CMYKRLE8:
                    case Compression.BI_CMYKRLE4:
                        compression = info.compression;
                        break;
                    default:
                        break;
                }

                // parse component format from the component masks
                if (info.compression == Compression.BI_BITFIELDS || info.compression == Compression.BI_ALPHABITFIELDS)
                {
                    assert(bits == 16 || bits == 32);

                    const(BMPInfo!4)* i4 = infoHeader!(BMPInfo!4)();
                    uint alphaMask = bmpVer >= 3 || info.compression == Compression.BI_ALPHABITFIELDS ? i4.alphaMask : 0;
                    uint unusedMask = ~(i4.redMask | i4.greenMask | i4.blueMask | alphaMask);

                    // this is a horrible loop to find the arrangement of components
                    uint bit = 0, numComponents = 0;
                    uint[5] componentWidth;
                    while (bit < bits)
                    {
                        uint currentMask;
                        uint startBit = bit;
                        if ((1u << bit) & i4.redMask)
                        {
                            currentMask = i4.redMask;
                            format ~= 'r';
                        }
                        else if ((1u << bit) & i4.greenMask)
                        {
                            currentMask = i4.greenMask;
                            format ~= 'g';
                        }
                        else if ((1u << bit) & i4.blueMask)
                        {
                            currentMask = i4.blueMask;
                            format ~= 'b';
                        }
                        else if ((1u << bit) & alphaMask)
                        {
                            currentMask = alphaMask;
                            format ~= 'a';
                        }
                        else
                        {
                            currentMask = unusedMask;
                            format ~= 'x';
                        }
                        while ((1u << ++bit) & currentMask) {}
                        assert(bit == bits || (~((1u << bit) - 1) & currentMask) == 0, "Invalid bitfields: Mask bits must be contiguous");
                        componentWidth[numComponents++] = bit - startBit;
                    }

                    // if components aren't all 8 bits, append component widths
                    bool allEight = true;
                    for (uint i = 0; i < numComponents; ++i)
                        allEight = allEight && componentWidth[i] == 8;
                    if (!allEight)
                    {
                        for (uint i = 0; i < numComponents; ++i)
                            format ~= '_' ~ formatInt(componentWidth[i]);
                    }
                    format ~= '\0';
                }

                md.horizDpi = info.xPelsPerMeter / 39.37007874;
                if (info.xPelsPerMeter && info.yPelsPerMeter)
                    md.pixelAspect = cast(float)info.xPelsPerMeter / cast(float)info.yPelsPerMeter;
                break;
        }

        if (!format) switch(bits)
        {
            case 16: format = "bgrx_5_5_5_1"; break;
            case 24: format = "bgr";          break;
            case 32: format = "bgrx";         break;
            default:
                // 0, 1, 2, 4, 8
                format = bmpVer < 3 ? "bgr" : "bgrx";
                break;
        }

        inout(ubyte)* imageData = cast(inout(ubyte)*)data.ptr + (bmpVer == 1 ? 10 : header().offBits);

        if (bits <= 8)
        {
            // palette expansion...
            if (paletteLength == 0)
                paletteLength = 1 << bits;

            ubyte unpackBits = bmpVer < 3 ? 24 : 32;
            ubyte unpackBytes = unpackBits / 8;
            uint unpackPitch = (((unpackBits * width) / 8) + 3) & ~3;

            ubyte[] raw = new ubyte[unpackPitch * height];

            if (compression == Compression.BI_RGB)
            {
                imageData = topDown ? imageData : imageData + (height - 1)*pitch;
                ubyte* destLine = raw.ptr;
                foreach (y; 0 .. height)
                {
                    for (size_t x = 0, bit = 0; x < width*unpackBytes; x += unpackBytes, bit += bits)
                    {
                        size_t byteOffset = bit / 8;
                        size_t index = (imageData[byteOffset] >> ((8 - bits) - (bit % 8))) & ((1 << bits) - 1);
                        if (index >= paletteLength)
                            destLine[x .. x + unpackBytes] = 0; // out of palette; assign black
                        else
                            destLine[x .. x + unpackBytes] = paletteData[index * unpackBytes .. index * unpackBytes + unpackBytes];
                    }
                    if (topDown)
                        imageData += pitch;
                    else
                        imageData -= pitch;
                    destLine += unpackPitch;
                }
            }
            else if (compression == Compression.BI_RLE8 || compression == Compression.BI_CMYKRLE8)
            {
                ubyte* destLine = raw.ptr;
                ubyte* destPixel = destLine;
                ubyte* eol = destLine + unpackBytes*width;
                ubyte* end = destLine + unpackPitch*height;
                outer: while(true)
                {
                    ubyte count = *imageData++;
                    if (count == 0)
                    {
                        // raw data
                        count = *imageData++;

                        if (count == 0)
                        {
                            // end of scanline
                            destLine += unpackPitch;
                            if (destLine >= end)
                                break;
                            destPixel = destLine;
                            eol = destLine + unpackBytes*width;
                        }
                        else if (count == 1)
                        {
                            // end of image
                            break;
                        }
                        else if (count == 2)
                        {
                            // delta code
                            ubyte x = *imageData++;
                            ubyte y = *imageData++;
                            destPixel += unpackBytes*x; // what if is past end of line?
                            destPixel += unpackPitch*y;
                            destLine += unpackPitch*y;
                            if (destLine >= end)
                                break;
                            eol = destLine + unpackBytes*width;
                        }
                        else
                        {
                            // take count
                            foreach (i; 0 .. count)
                            {
                                if (destPixel == eol)
                                {
                                    destLine += unpackPitch;
                                    if (destLine >= end)
                                        break outer;
                                    destPixel = destLine;
                                    eol = destLine + unpackBytes*width;
                                }

                                ubyte value = *imageData++;
                                destPixel[0 .. unpackBytes] = paletteData[value * unpackBytes .. value * unpackBytes + unpackBytes];
                                destPixel += unpackBytes;
                            }
                            if (count & 1)
                                imageData++;
                        }
                    }
                    else
                    {
                        // run length
                        ubyte value = *imageData++;
                        foreach (i; 0 .. count)
                        {
                            if (destPixel == eol)
                            {
                                destLine += unpackPitch;
                                if (destLine >= end)
                                    break outer;
                                destPixel = destLine;
                                eol = destLine + unpackBytes*width;
                            }

                            destPixel[0 .. unpackBytes] = paletteData[value * unpackBytes .. value * unpackBytes + unpackBytes];
                            destPixel += unpackBytes;
                        }
                    }
                }
            }
            else if (compression == Compression.BI_RLE4 || compression == Compression.BI_CMYKRLE4)
            {
            }

            bits = unpackBits;
            pitch = unpackPitch;
            imageData = cast(inout(ubyte)*)raw.ptr;
        }
        else if (compression == Compression.BI_JPEG)
        {
            assert(false);
        }
        else if (compression == Compression.BI_PNG)
        {
            assert(false);
        }

        MetaData* metadata = null;
        if (md != md.init)
        {
            void[] mem = new void[MetaData.sizeof + CommonMetadata.sizeof];
            metadata = cast(MetaData*)mem.ptr;
            metadata.magic = CommonMetadata.ID;
            metadata.bytes = CommonMetadata.sizeof;
            metadata.next = null;

            CommonMetadata* common = cast(CommonMetadata*)metadata.data().ptr;
            *common = md;
        }

        return inout(ImageBuffer)(
            width, height,
            pitch,
            1, 1,
            bits,
            0,
            imageData,
            format.ptr,
            cast(inout(MetaData*))metadata
        );
    }
}


enum Compression : uint
{
    BI_RGB = 0x0000,
    BI_RLE8 = 0x0001,
    BI_RLE4 = 0x0002,
    BI_BITFIELDS = 0x0003, // OS22XBITMAPHEADER: Huffman 1D
    BI_JPEG = 0x0004,      // OS22XBITMAPHEADER: RLE-24
    BI_PNG = 0x0005,
    BI_ALPHABITFIELDS = 0x0006,
    BI_CMYK = 0x000B,
    BI_CMYKRLE8 = 0x000C,
    BI_CMYKRLE4 = 0x000D
}

enum LogicalColorSpace
{
    LCS_CALIBRATED_RGB = 0x00000000,
    LCS_sRGB = 0x73524742,
    LCS_WINDOWS_COLOR_SPACE = 0x57696E20,
    PROFILE_LINKED = 0x4C494E4B,
    PROFILE_EMBEDDED = 0x4D424544
}

enum GamutMappingIntent
{
    LCS_GM_ABS_COLORIMETRIC = 0x00000008,
    LCS_GM_BUSINESS = 0x00000001,
    LCS_GM_GRAPHICS = 0x00000002,
    LCS_GM_IMAGES = 0x00000004
}

struct FP2Dot30
{
    @property double asFloat() const { return cast(double)_2dot30 * (1.0 / (1 << 30)); }
    alias asFloat this;

    uint _2dot30;
}

struct FP16Dot16
{
    @property double asFloat() const { return cast(double)_16dot16 * (1.0 / (1 << 16)); }
    alias asFloat this;

    uint _16dot16;
}

struct XYZ_FP
{
    FP2Dot30 x;
    FP2Dot30 y;
    FP2Dot30 z;
}

struct XYZTriple
{
    XYZ_FP red;
    XYZ_FP green;
    XYZ_FP blue;
}

struct BMPFileHeader
{
    align(2):
    char[2] type = "BM";
    uint    size; // file size
    ushort  reserved1;
    ushort  reserved2;
    uint    offBits;
}

struct BMPInfoV1
{
    ushort type;
    ushort width;
    ushort height;
    ushort byteWidth;
    ubyte planes;
    ubyte bitsPerPixel;
}

struct BMPInfo(int ver)
{
    static assert (ver >= 2);

align(2):
    uint            size = BMPInfo!ver.sizeof;

    static if (ver == 2)
    {
        ushort  width;
        ushort  height;
    }
    else
    {
        int     width;
        int     height;
    }
    ushort      planes = 1;
    ushort      bitCount;

    static if(ver >= 3)
    {
        Compression compression;
        uint        sizeImage;
        int         xPelsPerMeter;
        int         yPelsPerMeter;
        uint        clrUsed;
        uint        clrImportant;
    }
    static if(ver >= 4)
    {
        uint                redMask;
        uint                greenMask;
        uint                blueMask;
        uint                alphaMask;
        LogicalColorSpace   csType;
        XYZTriple           endpoints;
        FP16Dot16           gammaRed;
        FP16Dot16           gammaGreen;
        FP16Dot16           gammaBlue;
    }
    static if(ver >= 5)
    {
        GamutMappingIntent  intent;
        uint                profileData;
        uint                profileSize;
        uint                reserved;
    }
}
