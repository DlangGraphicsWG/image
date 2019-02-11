module wg.format.bmp;

import wg.image.imagebuffer;
import wg.image.metadata;


struct BMPImage
{
    void[] data;

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

    BMPFileHeader* header() const
    {
        return cast(BMPFileHeader*)&data[0];
    }

    int bmpVersion() const
    {
        if (*cast(ushort*)&data[0] == 0)
            return 1;
        const(uint) size = *cast(const(uint)*)(header() + 1);
        switch (size)
        {
            case BMPInfoV2.sizeof:
                return 2;
            case BMPInfoV3.sizeof:
                return 3;
            case BMPInfoV4.sizeof:
                return 4;
            case BMPInfoV5.sizeof:
                return 5;
            default:
                return 0;
        }
    }

    const(Info)* infoHeader(Info)() const
    {
        static if (is(Info == BMPInfoV1))
            return cast(const(Info)*)&data[0];
        else
            return cast(const(Info)*)(header() + 1);
    }

    const(void)[] iccData() const
    {
        if (bmpVersion() < 5)
            return null;
        const(BMPInfoV5)* info = infoHeader!BMPInfoV5();
        return (cast(void*)info + info.profileData)[0 .. info.profileSize];
    }

    inout(ImageBuffer) getImage() inout
    {
        import wg.util.format : formatInt;

        ImageBuffer img;
        CommonMetadata md;

        string cs = "sRGB";
        string format;
        uint width, height;
        uint pitch;
        ubyte bits;
        bool topDown = false;

        // TODO: no paletted images...

        int bmpVer = bmpVersion();
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
                const(BMPInfoV2)* info = infoHeader!BMPInfoV2();

                assert(info.planes == 1 && info.bitCount < 256);
                bits = cast(ubyte)info.bitCount;

                width = info.width;
                height = info.height;

                pitch = (((bits * width) / 8) + 3) & ~3;
                break;
            case 5:
                const(BMPInfoV5)* info = infoHeader!BMPInfoV5();

                // what is 'intent'?

                goto case 4;
            case 4:
                const(BMPInfoV4)* info = infoHeader!BMPInfoV4();

                // check csType...

                goto case 3;
            case 3:
                const(BMPInfoV3)* info = infoHeader!BMPInfoV3();

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

                assert(info.clrUsed == 0);

                // parse component format from the component masks
                if (info.compression == Compression.BI_BITFIELDS || info.compression == Compression.BI_ALPHABITFIELDS)
                {
                    assert(bits == 16 || bits == 32);

                    const(BMPInfoV4)* i4 = infoHeader!BMPInfoV4();
                    uint alphaMask = bmpVer >= 3 || info.compression == Compression.BI_ALPHABITFIELDS ? i4.alphaMask : 0;
                    uint unusedMask = ~(i4.redMask | i4.greenMask | i4.blueMask | alphaMask);

                    // this is a horrible loop to find the arrangement of components
                    uint bit = 0, numComponents = 0;
                    uint[5] componentWidth;
                    while (bit < bits)
                    {
                        uint currentMask;
                        uint startBit = bit;
                        if ((1 << bit) & i4.redMask)
                        {
                            currentMask = i4.redMask;
                            format ~= 'r';
                        }
                        else if ((1 << bit) & i4.greenMask)
                        {
                            currentMask = i4.greenMask;
                            format ~= 'g';
                        }
                        else if ((1 << bit) & i4.blueMask)
                        {
                            currentMask = i4.blueMask;
                            format ~= 'b';
                        }
                        else if ((1 << bit) & alphaMask)
                        {
                            currentMask = alphaMask;
                            format ~= 'a';
                        }
                        else
                        {
                            currentMask = unusedMask;
                            format ~= 'x';
                        }
                        while ((1 << ++bit) & currentMask) {}
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
                assert(0);
        }

        return inout(ImageBuffer)(
            width, height,
            pitch,
            1, 1,
            bits,
            0,
            data.ptr + header().offBits,
            format.ptr,
            null
        );
    }
}


unittest
{
    import std.file;
    import wg.image;
    import wg.color.rgb;

    void[] file = read("rgba16-4444.bmp");

    auto bmp = BMPImage(file);
    ImageBuffer buf = bmp.getImage();

    auto img = Image!(RGB!"bgr")(buf);
    auto pix = img.at(0, 0);
}


private:

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
    char[2] type; // "BM"
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

struct BMPInfoV2
{
    align(2):
    uint        size;
    ushort      width;
    ushort      height;
    ushort      planes;
    ushort      bitCount;
}

struct BMPInfoV3
{
    align(2):
    uint        size;
    int         width;
    int         height;
    ushort      planes;
    ushort      bitCount;
    Compression compression;
    uint        sizeImage;
    int         xPelsPerMeter;
    int         yPelsPerMeter;
    uint        clrUsed;
    uint        clrImportant;
}

struct BMPInfoV4
{
    align(2):
    BMPInfoV3   base;
    alias base this;

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

struct BMPInfoV5
{
    align(2):
    BMPInfoV4   base;
    alias base this;

    GamutMappingIntent  intent;
    uint                profileData;
    uint                profileSize;
    uint                reserved;
}

