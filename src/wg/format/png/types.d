module wg.format.png.types;

package enum ubyte[8] PNG_SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10];

package enum crcSize = 4;

package string allocationErrorMessage = "Allocation from the given allocator failed";

// All the following structs must not have padding
align(1):

/**
 * Each Chunk of data starts with this header and is then followed by length
 * bytes of data and then 4 more bytes of CRC checksum for data validation.
 */
package struct PngChunkHeader
{
    uint length;
    immutable(char)[4] type;
}

/// Stores a data from one png chunk and a link to the next one
struct PngChunk {
    ///
    char[4] type;
    ///
    ubyte[] data;
    ///
    PngChunk* next;
}

package enum char[4] HEADER_CHUNK_TYPE = "IHDR";


/// Defines the options that png supports for representing pixels
enum PngColorType: ubyte
{
    grayscale = 0,
    rgbColor = 2,
    paletteColor = 3,
    grayscaleWithAlpha = 4,
    rgbaColor = 6
}

package enum ubyte[7] pngColorTypeToSamples = [1, 0, 3, 1, 2, 0, 4];

/// The compression methods supported by PNG
enum PngCompressionMethod: ubyte
{
    deflate = 0
}

/// The filter methods supported by PNG
enum PngFilterMethod: ubyte
{
    adaptive = 0
}

/// The filter types supported by PNG adaptive filter method
enum PngFilterType: ubyte
{
    none = 0,
    sub = 1,
    up = 2,
    average = 3,
    paeth = 4,
}

/// The interlace methods supported by PNG
enum PngInterlaceMethod: ubyte
{
    noInterlace = 0,
    adam7 = 1
}

/// Header data from PNG file
struct PngHeaderData
{
    // Specification says width and height are unsigned but limited to 2^31 so we use
    // signed fields. That way code can directly use them in math with negative numbers.
    
    ///
    int width;
    
    ///
    int height;
    
    /// How many bits there are per sample. A pixel can have one (just grayscale) to four samples (rgba).
    /// Valid values are 1, 2, 4, 8 and 16
    ubyte bitDepth;
    
    /// How are pixels represented
    PngColorType colorType;
    
    /// What compression algorithm is used for the the image
    PngCompressionMethod compressionMethod;
    
    /// How are pixels filtered so that they are better compressed
    PngFilterMethod filterMethod;
    
    /// Is the image interlaced and how
    PngInterlaceMethod interlaceMethod;
}

package:

enum char[4] PALETTE_CHUNK_TYPE = "PLTE";

/*
 * Palette chunk contains length / 3 palette entries and each entry gives standard rgb 24bit color
 */
struct PngPaletteEntry
{
    ubyte red;
    ubyte green;
    ubyte blue;
}

/*
 * Image Data chunks needs to be put together and decompressed into scanlines where each
 * scan line begins with a filter byte followed by raw pixel bytes as specified in header.
 */
enum char[4] DATA_CHUNK_TYPE = "IDAT";

/*
 * Palette chunk contains a number of entries where each entry is 3 bytes: rgb and number
 * of entries is determined by chunk length.
 */
enum char[4] PLTE_CHUNK_TYPE = "PLTE";

/*
 * Chunk that marks the end of PNG data
 */
enum char[4] END_CHUNK_TYPE = "IEND";

//////////////////////////////////////////////////////////////
// Following are some of the optional chunks that seem useful
//////////////////////////////////////////////////////////////

/*
 * If colorType is palette color this chunk contains one byte alpha value for each palette entry.
 * For grayscale it contains two byte value between 0 and (2^bitDepth)-1. The gray color that
 * corresponds to that value is to be considered transparent.
 * For rgbColor it contains a 6 byte RGB value (RRGGBB) that is to be considered transparent.
 */
enum char[4] TRANSPARENCY_CHUNK_TYPE = "tRNS";

enum char[4] GAMMA_CHUNK_TYPE = "gAMA";

enum char[4] CHROMATICITIES_CHUNK_TYPE = "cHRM";

// We initialize it to values for sRGB and since we treat the image as sRGB even when
// Chromaticities are not given we can say that they are not given even when they were
// actually read from the file but are equal to these numbers.
struct Chromaticities {
    uint whiteX = 31_270;
    uint whiteY = 32_900;
    uint redX = 64_000;
    uint redY = 33_000;
    uint greenX = 30_000;
    uint greenY = 60_000;
    uint blueX = 15_000;
    uint blueY = 6_000;
    
    bool isSet() const nothrow @nogc
    { return this != Chromaticities.init; }

    bool isWhiteSet() const nothrow @nogc
    { return whiteX != Chromaticities.init.whiteX || whiteY != Chromaticities.init.whiteY; }
}

enum char[4] SRGB_CHUNK_TYPE = "sRGB";

