module wg.format.png.reader;

import wg.util.allocator;
import wg.format.png.types;
import wg.util.util: Result, asArrayOf;
import wg.image.imagebuffer;

// TODO: 
// 1. Make CommonMetadata using pHYs chunk data
// 2. Make PngChunks smarter so they keep their allocator and chunks can easily be added and removed
// 3. Check sRGB, gAMA and cHRM chunks and return the proper format string using them

private extern(C) nothrow @nogc
{
    import etc.c.zlib : z_stream, z_streamp, ZLIB_VERSION;

    // Had to copy function definitions from zlib here in order to add @nogc to them
    int inflateInit(z_streamp strm)
    {
        return inflateInit_(strm, ZLIB_VERSION.ptr, z_stream.sizeof);
    }
    int inflateInit_(z_streamp strm, const(char)* versionx, int stream_size);
    int inflate(z_streamp strm, int flush);
    int inflateEnd(z_streamp strm);
}

// Documentation (http://www.zlib.net/zlib_tech.html) says that zlib internaly
// requires up to about 44KB for inflate but we give it a bit more just to be safe
private enum zlibInflateMemory = 50 * 1024;

private extern(C) void* zallocFunc(void* opaque, uint items, uint size) nothrow @nogc
{
    auto loader = cast(PngLoadData*)opaque;
    auto res = &loader.zlibBuffer[loader.zlibBufferUsed];
    loader.zlibBufferUsed += items * size;
    if (loader.zlibBufferUsed >= zlibInflateMemory)
    {
        loader.withError("ZLib didn't have enough memory to complete decompression");
        return null;
    }
    return res;
}

private extern(C) void zfreeFunc(void* opaque, void* address) nothrow @nogc
{
    // No need to do anything since the whole memory will be freed at the end of the process
}

alias PngHeaderResult = Result!PngHeaderData;

/**
 * Loads and returns a PngHeaderResult from a given byte array.
 * Make sure to first check the result for error since other fields will have
 * undefined values in case of an error.
 */
PngHeaderResult loadPngHeader(const(ubyte)[] file) nothrow @nogc
{
    if (file.length < PNG_SIGNATURE.length) return PngHeaderResult("Png image file too short");
    immutable static pngSignature = PNG_SIGNATURE;
    if (file[0..PNG_SIGNATURE.length] != pngSignature) return PngHeaderResult("Png header missing");

    file = file[PNG_SIGNATURE.length..$];

    immutable chunkHeader = loadChunkHeader(file);
    if (chunkHeader.error) return PngHeaderResult(chunkHeader.error);

    if (chunkHeader.type != HEADER_CHUNK_TYPE)
        return PngHeaderResult("Png file doesn't start with the header chunk");

    if (chunkHeader.length != PngHeaderData.sizeof) 
        return PngHeaderResult("Invalid header chunk length");
    
    PngHeaderResult result = {value: *cast(PngHeaderData*)file.ptr};
    if (result.colorType > PngColorType.max || pngColorTypeToSamples[result.colorType] == 0)
    {
        return PngHeaderResult("Invalid color type found");
    }
    if (!result.bitDepth.isValid())
    {
        return PngHeaderResult("Invalid bit depth found");
    }
    import std.bitmanip : swapEndian;
    result.width = result.width.swapEndian;
    result.height = result.height.swapEndian;

    return result;
}

alias ImageResult = Result!ImageBuffer;

/// Loads the given byte array as Png image into an ImageBuffer
ImageResult loadPng(const ubyte[] file) nothrow
{
    PngChunk* chunks;
    return loadPng(file, getGcAllocator(), null, chunks);
}

/// Loads the given byte array as Png image into an ImageBuffer using the given allocator
ImageResult loadPng(const ubyte[] file, Allocator* allocator) nothrow @nogc
{
    PngChunk* chunks;
    return loadPng(file, allocator, null, chunks);
}

/**
 * Loads the given byte array as Png image into an ImageBuffer and also loads all other
 * present png chunks as a linked list of data
 */
ImageResult loadPng(const ubyte[] file, out PngChunk* chunks) nothrow
{
    return loadPng(file, getGcAllocator(), getGcAllocator(), chunks);
}

/**
 * Loads the given byte array as Png image into an ImageBuffer and also loads all other
 * present png chunks as a linked list of data. It uses the first given allocator for
 * image data and the other for png chunks. If the other allocator is null it will not
 * load the chunks.
 */
ImageResult loadPng(const ubyte[] file, Allocator* allocator,
            Allocator* chunkAllocator, out PngChunk* chunks) nothrow @nogc
{
    auto pngHeader = loadPngHeader(file);
    if (pngHeader.error) return ImageResult(pngHeader.error);

    auto loader = PngLoadData(file, pngHeader, allocator, chunkAllocator);

    if (loader.error) return ImageResult(loader.error);
    
    while (loader.loadPngChunk()) {}

    if (loader.error) return ImageResult(loader.error);

    return loader.result;
}

// Structures that holds all the data needed during decoding of PNG and contains operations that does the decoding
private struct PngLoadData {
    PngHeaderData info;
    alias info this;

    const(ubyte)[] data; // raw data
    PngPaletteEntry[] palette;
    // We want to have a full size transparency buffer even when actual transparency chunk is shorter
    // to simplify algorithm for moving it to alpha channel.
    ubyte[256] transparency;
    int transLength;
    ubyte[zlibInflateMemory] zlibBuffer;
    uint zlibBufferUsed;
    z_stream zStream;
    bool unzipDone;
    Allocator* allocator;
    Allocator* chunkAllocator;
    PngChunk* chunks;
    ubyte[] pixels; // decoded pixels
    int lineBytes;
    bool headerAddedToMeta;
    bool dataFound;
    uint gamma;
    Chromaticities chromaticities;
    bool isSRGB;
    ImageResult result;
    string error;

    this(const(ubyte)[] file, const PngHeaderData header, Allocator* a, Allocator* ca) nothrow @nogc
    {
        data = file[PNG_SIGNATURE.length..$];
        info = header;
        allocator = a;
        chunkAllocator = ca;

        import etc.c.zlib : Z_OK;
        if (inflateInit(&zStream) != Z_OK)
        {
            error = "Failed to initialize zlib for Png extraction";
            return;
        }
        
        lineBytes =  (bitDepth * pngColorTypeToSamples[colorType] * width + 7) / 8;
        if (interlaceMethod == PngInterlaceMethod.noInterlace)
        {
            zStream.avail_out = (lineBytes + 1) * height;
        }
        else
        {
            if (bitDepth < 8)
            {
                // Take enough space for worst case scenario which is if width is such that
                // only the first bitDepth bits of last byte of each row are used
                zStream.avail_out = (lineBytes + 1) * height;
            }
            else zStream.avail_out = lineBytes * height;
            // Now since each row starts with a filter byte we need to add space for them
            zStream.avail_out +=
                  (height - 1) / 8 + 1 // number of rows in pass 1
                + (height - 1) / 8 + 1 // number of rows in pass 2
                + (height - 5) / 8 + 1 // number of rows in pass 3
                + (height - 1) / 4 + 1 // number of rows in pass 4
                + (height - 3) / 4 + 1 // number of rows in pass 5
                + (height - 1) / 2 + 1 // number of rows in pass 6
                + (height - 2) / 2 + 1 // number of rows in pass 7
                ;
            // In case when width < 5 or height < 5 the above calculus might reserve a bit more
            // space than necessary but we accept that for simplicity.
        }

        pixels = cast(ubyte[])allocator.allocate(zStream.avail_out);
        if (pixels.length != zStream.avail_out)
        {
            result.error = "Allocation from the given allocator failed";
            return;
        }

        zStream.next_out = pixels.ptr;
        zStream.zalloc = &zallocFunc;
        zStream.zfree = &zfreeFunc;
        zStream.opaque = &this;

        result.width = width;
        result.height = height;
        result.rowPitch = lineBytes;
    }

    private bool loadPngChunk() nothrow @nogc
    {
        auto chunkHeader = loadChunkHeader(data);
        if (chunkHeader.error) return withError(chunkHeader.error);

        switch (chunkHeader.type)
        {
            case HEADER_CHUNK_TYPE:
                if (headerAddedToMeta) return withError("Duplicate Header chunk found");
                headerAddedToMeta = true;
                goto default;

            case DATA_CHUNK_TYPE:
                import etc.c.zlib : Z_OK, Z_STREAM_END, Z_NO_FLUSH;
                dataFound = true;
                zStream.avail_in = chunkHeader.length;
                zStream.next_in = data.ptr;
                while (zStream.avail_in != 0)
                {
                    immutable res = inflate(&zStream, Z_NO_FLUSH);
                    if (res == Z_STREAM_END)
                    {
                        inflateEnd(&zStream);
                        unzipDone = true;
                        break;
                    }
                    if (res != Z_OK)
                    {
                        inflateEnd(&zStream);
                        return withError("Failed decompressing the PNG file");
                    }
                }
                break;
            
            case TRANSPARENCY_CHUNK_TYPE:
                if (transLength > 0) return withError("Second transparency chunk encountered");
                if (colorType == PngColorType.paletteColor && chunkHeader.length > (1 << bitDepth))
                {
                    return withError("Transparency chunk too long");
                }
                transLength = chunkHeader.length;
                transparency[0..transLength] = data[0..transLength];
                transparency[transLength..$] = 0xff;
                goto default;
            
            case PALETTE_CHUNK_TYPE:
                if (palette.length > 0) return withError("Second palette chunk encountered");
                if (colorType != PngColorType.paletteColor &&
                    colorType != PngColorType.rgbColor &&
                    colorType != PngColorType.rgbaColor)
                {
                    return withError("Palette found in grayscale image");
                }
                if (chunkHeader.length > (1 << bitDepth) * PngPaletteEntry.sizeof)
                    return withError("Palette chunk length invalid");
                palette = data[0..chunkHeader.length].asArrayOf!PngPaletteEntry;
                goto default;
            
            case GAMMA_CHUNK_TYPE:
                gamma = *cast(uint*)data.ptr;
                goto default;

            case CHROMATICITIES_CHUNK_TYPE:
                chromaticities = *cast(Chromaticities*)data.ptr;
                goto default;
            
            case SRGB_CHUNK_TYPE:
                isSRGB = true;
                goto default;
            
            case END_CHUNK_TYPE:
                if (!dataFound) return withError("Png is missing data chunk");
                if (!unzipDone) return withError("Couldn't complete decompression of png file");
                if (interlaceMethod == PngInterlaceMethod.adam7) deinterlace();
                else 
                {
                    auto inputData = pixels;
                    auto output = pixels;
                    if (!defilter(inputData, output, lineBytes, height)) return false;
                }
                setupFormat();
                return false; // Here false can mean error if error field was set, or it can just mean end of reading process

            default:
                if (chunkAllocator == null) break;
                auto chunkMemory = chunkAllocator.allocate(PngChunk.sizeof + chunkHeader.length).asArrayOf!ubyte;
                if (chunkMemory.length != PngChunk.sizeof + chunkHeader.length)
                {
                    return withError("Allocation from the given chunk allocator failed");
                }
                auto mdata = cast(PngChunk*)chunkMemory.ptr;
                mdata.type[] = chunkHeader.type[];
                mdata.data = chunkMemory[PngChunk.sizeof..$];
                mdata.next = chunks;
                mdata.data[] = data[0..chunkHeader.length];
                chunks = mdata;
                break;
        }

        data = data[(chunkHeader.length + crcSize)..$];
        return true;
    }

    private bool deinterlace() nothrow @nogc
    {
        immutable int[7] passWidths = [
            (width - 1) / 8 + 1,
            (width + 3) / 8,
            (width - 1) / 4 + 1,
            (width + 1) / 4,
            (width - 1) / 2 + 1,
            width / 2,
            width
        ];
        immutable int[7] passHeights = [
            (height - 1) / 8 + 1,
            (height - 1) / 8 + 1,
            (height + 3) / 8,
            (height - 1) / 4 + 1,
            (height + 1) / 4,
            (height - 1) / 2 + 1,
            height / 2,
        ];
        immutable sampleBits = bitDepth * pngColorTypeToSamples[colorType];

        // First defilter each row in each interlaced subimage
        auto inputData = pixels;
        auto output = pixels;
        foreach (i, passWidth; passWidths)
        {
            if (passWidth == 0 || passHeights[i] == 0) continue;
            if (!defilter(inputData, output, (passWidth * sampleBits + 7) / 8, passHeights[i])) return false;
        }

        // If defiltering didn't fail allocate space for deinterlaced image and setup deallocation of old pixel data at the end
        auto newPixels = cast(ubyte[])allocator.allocate(lineBytes * height);
        if (newPixels.length != lineBytes * height) return withError("Allocation from the given allocator failed");
        scope (exit)
        {
            auto toDeallocate = pixels;
            pixels = newPixels;
            allocator.deallocate(toDeallocate);
        }

        if (bitDepth >= 8)
        {
            // Here we only need to work with whole bytes
            immutable samples = pngColorTypeToSamples[colorType];
            immutable bytesPerPixel = bitDepth * samples / 8;
            int i = 0;
            // Pass 1 and 2
            for (int startx = 0; startx < 5 * bytesPerPixel; startx += 4 * bytesPerPixel)
            {
                for (int y = 0; y < height; y += 8)
                {
                    immutable linePos = y * lineBytes;
                    for (int x = startx; x < lineBytes; x += 8 * bytesPerPixel)
                    {
                        immutable newPos = linePos + x;
                        newPixels[newPos..newPos + bytesPerPixel] = pixels[i..i + bytesPerPixel];
                        i += bytesPerPixel;
                    }
                }
            }
            // Pass 3 and 4
            for (int startx = 0; startx < 3 * bytesPerPixel; startx += 2 * bytesPerPixel)
            {
                immutable starty = startx == 0 ? 4 : 0;
                immutable yinc = startx == 0 ? 8 : 4;
                for (int y = starty; y < height; y += yinc)
                {
                    immutable linePos = y * lineBytes;
                    for (int x = startx; x < lineBytes; x += 4 * bytesPerPixel)
                    {
                        immutable newPos = linePos + x;
                        newPixels[newPos..newPos + bytesPerPixel] = pixels[i..i + bytesPerPixel];
                        i += bytesPerPixel;
                    }
                }
            }
            // Pass 5 and 6
            for (int startx = 0; startx < 2 * bytesPerPixel; startx += bytesPerPixel)
            {
                immutable starty = startx == 0 ? 2 : 0;
                immutable yinc = startx == 0 ? 4 : 2;
                for (int y = starty; y < height; y += yinc)
                {
                    immutable linePos = y * lineBytes;
                    for (int x = startx; x < lineBytes; x += 2 * bytesPerPixel)
                    {
                        immutable newPos = linePos + x;
                        newPixels[newPos..newPos + bytesPerPixel] = pixels[i..i + bytesPerPixel];
                        i += bytesPerPixel;
                    }
                }
            }
            // Pass 7
            for (int y = 1; y < height; y += 2)
            {
                immutable newPos = y * lineBytes;
                newPixels[newPos..newPos + lineBytes] = pixels[i..i + lineBytes];
                i += lineBytes;
            }
        }
        else // if (bitDepth < 8)
        {
            import core.bitop: ror;
            int i = 0; // Counter over bytes
            int ic = 0; // Counter over bits
            immutable ubyte andMask = cast(ubyte)((1 << bitDepth) - 1);
            immutable ubyte startShift = cast(ubyte)(8 - bitDepth);
            immutable ubyte startMask = cast(ubyte)(andMask << startShift);
            // Pass 1 and 2
            for (int pass = 0; pass < 2; pass++)
            {
                immutable startx = pass * (4 * bitDepth / 8);
                immutable newBitShift = (24 - (pass * 4 + 1) * bitDepth) % 8;
                for (int y = 0; y < height; y += 8)
                {
                    ubyte shift = startShift;
                    ubyte mask = startMask;
                    immutable linePos = y * lineBytes;
                    for (int x = startx; x < lineBytes; x += bitDepth)
                    {
                        newPixels[linePos + x] |= cast(ubyte)((((pixels[i] & mask) >> shift) & andMask) << newBitShift);
                        shift = (shift + 8 - bitDepth) & 0x7;
                        mask = ror(mask, cast(uint)bitDepth);
                        ic += bitDepth;
                        i = ic >> 3;
                    }
                    i = (ic + 7) >> 3;
                    ic = i << 3;
                }
            }
            // Pass 3 and 4
            for (int pass = 0; pass < 2; pass++)
            {
                immutable startx = pass * (2 * bitDepth / 8);
                immutable starty = (1 - pass) * 4;
                immutable newBitShift = (16 - (pass * 2 + 1) * bitDepth) % 8;
                immutable newBitShift2 = bitDepth == 1 ? newBitShift - 4 : newBitShift;
                immutable yinc = pass == 0 ? 8 : 4;
                for (int y = starty; y < height; y += yinc)
                {
                    ubyte shift = startShift;
                    ubyte mask = startMask;
                    immutable linePos = y * lineBytes;
                    for (int x = startx; x < lineBytes; x += bitDepth)
                    {
                        newPixels[linePos + x] |= (((pixels[i] & mask) >> shift) & andMask) << newBitShift;
                        shift = (shift + 8 - bitDepth) & 0x7;
                        mask = ror(mask, cast(uint)bitDepth);
                        ic += bitDepth;
                        i = ic >> 3;

                        immutable nextPos = linePos + x + bitDepth / 2;
                        if (nextPos >= linePos + lineBytes) break;
                        newPixels[nextPos] |= (((pixels[i] & mask) >> shift) & andMask) << newBitShift2;
                        shift = (shift + 8 - bitDepth) & 0x7;
                        mask = ror(mask, bitDepth);
                        ic += bitDepth;
                        i = ic >> 3;
                    }
                    i = (ic + 7) >> 3;
                    ic = i << 3;
                }
            }
            // Pass 5 and 6
            for (int pass = 0; pass < 2; pass++)
            {
                immutable starty = 2 - pass * 2;
                immutable yinc = 4 - pass * 2;
                immutable newBitShift = 8 - (pass + 1) * bitDepth;
                immutable shiftOffset = 8 - 2 * bitDepth;
                immutable newBitShift2 = (newBitShift + shiftOffset) % 8;
                immutable newBitShift3 = (newBitShift2 + shiftOffset) % 8;
                immutable newBitShift4 = (newBitShift3 + shiftOffset) % 8;
                for (int y = starty; y < height; y += yinc)
                {
                    ubyte shift = startShift;
                    ubyte mask = startMask;
                    immutable linePos = y * lineBytes;
                    for (int x = 0; x < lineBytes; x += bitDepth)
                    {
                        newPixels[linePos + x] |= (((pixels[i] & mask) >> shift) & andMask) << newBitShift;
                        shift = (shift + 8 - bitDepth) & 0x7;
                        mask = ror(mask, bitDepth);
                        ic += bitDepth;
                        i = ic >> 3;

                        int nextPos = linePos + x + bitDepth / 4;
                        if (nextPos >= linePos + lineBytes) break;
                        newPixels[nextPos] |= (((pixels[i] & mask) >> shift) & andMask) << newBitShift2;
                        shift = (shift + 8 - bitDepth) & 0x7;
                        mask = ror(mask, bitDepth);
                        ic += bitDepth;
                        i = ic >> 3;

                        nextPos = linePos + x + bitDepth / 2;
                        if (nextPos >= linePos + lineBytes) break;
                        newPixels[nextPos] |= (((pixels[i] & mask) >> shift) & andMask) << newBitShift3;
                        shift = (shift + 8 - bitDepth) & 0x7;
                        mask = ror(mask, bitDepth);
                        ic += bitDepth;
                        i = ic >> 3;

                        nextPos = linePos + x + bitDepth - 1;
                        if (nextPos >= linePos + lineBytes) break;
                        newPixels[nextPos] |= (((pixels[i] & mask) >> shift) & andMask) << newBitShift4;
                        shift = (shift + 8 - bitDepth) & 0x7;
                        mask = ror(mask, bitDepth);
                        ic += bitDepth;
                        i = ic >> 3;
                    }
                    i = (ic + 7) >> 3;
                    ic = i << 3;
                }
            }
            // Pass 7
            for (int y = 1; y < height; y += 2)
            {
                immutable linePos = y * lineBytes;
                newPixels[linePos..linePos + lineBytes] = pixels[i..i + lineBytes];
                i += lineBytes;
            }
        }
        return true;
    }

    private bool defilter(ref ubyte[] inputData, ref ubyte[] output, int bytesInLine, int h) nothrow @nogc
    {
        immutable sampleNum = pngColorTypeToSamples[colorType];
        immutable prev = (bitDepth + 7) / 8 * sampleNum;
        auto prevRow = output;
        {
            //process first line special
            immutable filter = inputData[0];
            if (filter > PngFilterType.max) return withError("Invalid filter type detected");
            auto input = inputData[1..bytesInLine + 1];
            final switch (filter) {
                case PngFilterType.none, PngFilterType.up:
                    foreach (i; 0..input.length) output[i] = input[i];
                    break;

                case PngFilterType.sub, PngFilterType.paeth:
                    foreach (i; 0..prev) output[i] = input[i];
                    foreach (i; prev..input.length) output[i] = cast(ubyte)(output[i-prev] + input[i]);
                    break;

                case PngFilterType.average:
                    foreach (i; 0..prev) output[i] = input[i];
                    foreach (i; prev..input.length) output[i] = cast(ubyte)(output[i-prev] / 2 + input[i]);
                    break;
            }
            output = output[bytesInLine..$];
            inputData = inputData[bytesInLine + 1..$];
        }
        foreach (row; 1..h) 
        {
            immutable filter = inputData[0];
            if (filter > PngFilterType.max) return withError("Invalid filter type detected");
            auto input = inputData[1..bytesInLine + 1];
            final switch (filter)
            {
                case PngFilterType.none:
                    foreach (i; 0..input.length) output[i] = input[i];
                    break;

                case PngFilterType.sub:
                    foreach (i; 0..prev) output[i] = input[i];
                    foreach (i; prev..input.length) output[i] = cast(ubyte)(output[i-prev] + input[i]);
                    break;

                case PngFilterType.up:
                    foreach (i; 0..input.length) output[i] = cast(ubyte)(prevRow[i] + input[i]);
                    break;

                case PngFilterType.average:
                    foreach (i; 0..prev) output[i] = cast(ubyte)(prevRow[i] / 2 + input[i]);
                    foreach (i; prev..input.length)
                        output[i] = cast(ubyte)((prevRow[i] + output[i - prev]) / 2 + input[i]);
                    break;
                
                case PngFilterType.paeth:
                    foreach (i; 0..prev) output[i] = cast(ubyte)(prevRow[i] + input[i]);
                    foreach (i; prev..input.length)
                    {
                        immutable paethVal = paeth(output[i - prev], prevRow[i], prevRow[i - prev]);
                        output[i] = cast(ubyte)(paethVal + input[i]);
                    }
                    break;
            }
            prevRow = output;
            output = output[bytesInLine..$];
            inputData = inputData[bytesInLine + 1..$];
        }
        return true;
    }

    private bool moveGrayscaleTransparencyToAlpha() nothrow @nogc
    {
        immutable newLineBytes = (bitDepth * 2 * width + 7) / 8;
        immutable newTotalBytes = newLineBytes * height;
        auto output = cast(ubyte[])allocator.allocate(newTotalBytes);
        if (output.length != newTotalBytes) return withError("Failed allocating pixels data from the given allocator");
        auto input = pixels;
        auto toDeallocate = pixels;
        scope (exit) allocator.deallocate(toDeallocate);
        pixels = output;

        if (bitDepth == 16)
        {
            auto input16 = input.asArrayOf!ushort;
            auto output16 = output.asArrayOf!ushort;
            immutable transparency16 = transparency.asArrayOf!ushort[0];
            foreach (y; 0..height)
            {
                int writePos = 0;
                foreach (x; 0..width)
                {
                    output16[writePos++] = input16[x];
                    output16[writePos++] = input16[x] == transparency16 ? 0 : 0xffff;
                }
                output16 = output16[writePos..$];
                input16 = input16[width..$];
            }
        }
        else
        {
            immutable ubyte mask = cast(ubyte)((1 << bitDepth) - 1);
            immutable int samplesInByte = 8 / bitDepth;
            foreach (y; 0..height)
            {
                int writePos = 0;
                foreach (x; 0..lineBytes)
                {
                    ushort outputVal = 0;
                    foreach (n; 1..samplesInByte + 1)
                    {
                        immutable pixValue = (input[x] >> (8 - bitDepth * n)) & mask;
                        immutable alphaValue = pixValue == transparency[1] ? 0 : mask;
                        outputVal |= pixValue << (16 - bitDepth * (2 * n - 1));
                        outputVal |= alphaValue << (16 - bitDepth * 2 * n);
                    }
                    output[writePos++] = outputVal >> 8;
                    if (writePos >= newLineBytes) break; // Last byte of the line might not be used in whole
                    output[writePos++] = outputVal & 0xff;
                }
                output = output[newLineBytes..$];
                input = input[lineBytes..$];
            }
        }

        result.rowPitch = newLineBytes;
        return true;
    }

    private bool depalettize() nothrow @nogc
    {
        immutable pixelSize = transLength > 0 ? 4 : 3;
        immutable newLineBytes = pixelSize * width;
        immutable newTotalBytes = newLineBytes * height;
        auto output = cast(ubyte[])allocator.allocate(newTotalBytes);
        if (output.length != newTotalBytes) return withError("Failed allocating pixels data from the given allocator");
        auto input = pixels;
        auto toDeallocate = pixels;
        scope (exit) allocator.deallocate(toDeallocate);
        pixels = output;

        immutable ubyte mask = cast(ubyte)((1 << bitDepth) - 1);
        immutable int samplesInByte = 8 / bitDepth;
        foreach (y; 0..height)
        {
            int writePos = 0;
            foreach (x; 0..lineBytes)
            {
                foreach (n; 1..samplesInByte + 1)
                {
                    immutable index = (input[x] >> (8 - bitDepth * n)) & mask;
                    immutable entry = palette[index];
                    output[writePos++] = entry.red;
                    output[writePos++] = entry.green;
                    output[writePos++] = entry.blue;
                    if (pixelSize == 4) output[writePos++] = transparency[index];
                    if (writePos >= newLineBytes) break; // Last byte of the line might not be used in whole
                }
            }
            output = output[newLineBytes..$];
            input = input[lineBytes..$];
        }
        result.rowPitch = pixelSize * width;
        return true;
    }

    private bool moveRgbTransparencyToAlpha() nothrow @nogc
    {
        immutable newLineBytes = bitDepth * 4 * width / 8;
        immutable newTotalBytes = newLineBytes * height;
        auto output = cast(ubyte[])allocator.allocate(newTotalBytes);
        if (output.length != newTotalBytes) return withError("Failed allocating pixels data from the given allocator");
        auto input = pixels;
        auto toDeallocate = pixels;
        scope (exit) allocator.deallocate(toDeallocate);
        pixels = output;

        immutable int samples = width * 3;

        if (bitDepth == 16)
        {
            auto input16 = input.asArrayOf!ushort;
            auto output16 = output.asArrayOf!ushort;
            immutable transparency16 = transparency.asArrayOf!ushort;
            foreach (y; 0..height)
            {
                int writePos = 0;
                int x = 0;
                while (x < samples)
                {
                    output16[writePos++] = input16[x];
                    output16[writePos++] = input16[x+1];
                    output16[writePos++] = input16[x+2];
                    if (input16[x..x + 3] == transparency16[0..3]) output16[writePos++] = 0;
                    else output16[writePos++] = 0xffff;
                    x += 3;
                }
                output16 = output16[writePos..$];
                input16 = input16[samples..$];
            }
        }
        else
        {
            foreach (y; 0..height)
            {
                int writePos = 0;
                int x = 0;
                while (x < samples)
                {
                    output[writePos++] = input[x];
                    output[writePos++] = input[x+1];
                    output[writePos++] = input[x+2];
                    if (input[x..x + 2] == transparency[0..3]) output[writePos++] = 0;
                    else output[writePos++] = 0xff;
                    x += 3;
                }
                output = output[newLineBytes..$];
                input = input[lineBytes..$];
            }
        }

        result.rowPitch = newLineBytes;
        return true;
    }

    private bool setupFormat() nothrow @nogc
    {
        static immutable string[] formats = [
            "",
            "l_1",
            "l_2",
            "l_4",
            "l",
            "l_16",
            "rgb",
            "rgb_16_16_16",

            "",
            "la_1_1",
            "la_2_2",
            "la_4_4",
            "la",
            "la_16_16",
            "rgba",
            "rgba_16_16_16_16",
        ];

        int intFormat;
        import core.bitop: bsf;
        final switch (colorType)
        {
            case PngColorType.grayscale:
                intFormat = bitDepth.bsf() + 1;
                if (transLength > 0)
                {
                    if (!moveGrayscaleTransparencyToAlpha()) return false;
                    intFormat |= 8;
                }
                break;
            case PngColorType.grayscaleWithAlpha:
                intFormat = 8 | (bitDepth.bsf() + 1);
                break;
            case PngColorType.paletteColor:
                intFormat = 6;
                if (!depalettize()) return false;
                if (transLength > 0) intFormat |= 8;
                break;
            case PngColorType.rgbColor:
                intFormat = bitDepth == 8 ? 6 : 7;
                if (transLength > 0) 
                {
                    if (!moveRgbTransparencyToAlpha()) return false;
                    intFormat |= 8;
                }
                break;
            case PngColorType.rgbaColor:
                intFormat = bitDepth == 8 ? 14 : 15;
                break;
        }

        switch (intFormat) {
            case     1, 2, 3, 4, 5: result.bitsPerBlock = bitDepth; break;
            case              6, 7: result.bitsPerBlock = cast(ubyte)(3 * bitDepth); break;
            case 9, 10, 11, 12, 13: result.bitsPerBlock = cast(ubyte)(2 * bitDepth); break;
            case            14, 15: result.bitsPerBlock = cast(ubyte)(4 * bitDepth); break;
            default:                result.bitsPerBlock = 0; break;
        }

        auto strFormat = formats[intFormat];

        if (!isSRGB)
        {
            if (chromaticities.isSet)
            {
                // TODO: Read chromaticities and try to find standard RGB color space that mathes.
                // If found and it is not sRGB add its name to strFormat using allocator.
                // If not found add string in the format "@{wX, wY}R{rX, rY}G{gX, gY}B{bX, bY}".
            }
            else if (gamma != 0 && gamma != 45_455) // standard sRGB gamma
            {
                // TODO: Calculate g as 1/gamma and add "^g" to strformat using allocator
            }
        }

        result.data = pixels.ptr;
        result.pixelFormat = strFormat.ptr;
        return true;
    }

    private bool withError(string message) nothrow @nogc
    {
        error = message;
        PngChunk* nextChunk;
        for (auto chunk = chunks; chunk != null; chunk = nextChunk)
        {
            nextChunk = chunk.next;
            chunkAllocator.deallocate((cast(ubyte*)chunk)[0..PngChunk.sizeof + chunk.data.length]);
        }
        allocator.deallocate(pixels);
        chunks = null;
        pixels = [];
        return false;
    }
}

private Result!PngChunkHeader loadChunkHeader(ref const(ubyte)[] file) nothrow @nogc
{
    if (file.length < PngChunkHeader.sizeof) 
    {
        return Result!PngChunkHeader("End of file reached too soon");
    }
    auto chunkHeader = *cast(PngChunkHeader*)file.ptr;
    import std.bitmanip : swapEndian;
    chunkHeader.length = chunkHeader.length.swapEndian;

    if (file.length < PngChunkHeader.sizeof + chunkHeader.length + crcSize)
    {
        return Result!PngChunkHeader("File size and chunk size mismatch");
    }

    {
        import std.digest.crc : crc32Of;
        import std.algorithm: reverse;
        auto crcPart = file[4..chunkHeader.length + 8];
        immutable crc = crc32Of(crcPart)[].reverse;
        immutable crcStart = PngChunkHeader.sizeof + chunkHeader.length;
        auto const actualCrc = file[crcStart..crcStart + 4];
        if (crc != actualCrc) 
        {
            return Result!PngChunkHeader("CRC check failed");
        }
    }

    file = file[PngChunkHeader.sizeof..$];
    return Result!PngChunkHeader(null, chunkHeader);
}

/*
 * Performs the paeth PNG filter from pixels values:
 *   a = back
 *   b = up
 *   c = up and back
 */
private pure ubyte paeth(ubyte a, ubyte b, ubyte c) nothrow @nogc
{
    int pa = b - c;
    int pb = a - c;
    int pc = pa + pb;
    if (pa < 0) pa = -pa;
    if (pb < 0) pb = -pb;
    if (pc < 0) pc = -pc;
    if (pa <= pb && pa <= pc) return a;
    else if (pb <= pc) return b;
    else return c;
}
