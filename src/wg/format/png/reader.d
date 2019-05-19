module wg.format.png.reader;

import wg.util.allocator;
import wg.format.png.types;
import wg.util.util: Result, asArrayOf;
import wg.image.imagebuffer;

// TODO: 
// 1. Make CommonMetadata using pHYs chunk data
// 2. Make PngChunks smarter so they keep their allocator and chunks can easily be added and removed
// 3. Check sRGB, gAMA and cHRM chunks and return the proper format string using them


///
enum PngError
{
    success,
    failure,
    invalid,
    corrupt
}

///
alias PngHeaderResult = Result!(PngHeaderData, PngError);

///
alias ImageResult = Result!(ImageBuffer, PngError);

/**
 * Loads and returns a PngHeaderResult from a given byte array.
 * Make sure to first check the result for error since other fields will have
 * undefined values in case of an error.
 */
PngHeaderResult loadPngHeader(const(ubyte)[] file) nothrow @nogc
{
    if (file.length < PNG_SIGNATURE.length)
        return PngHeaderResult(PngError.invalid, "Png image file too short");
    immutable static pngSignature = PNG_SIGNATURE;
    if (file[0..PNG_SIGNATURE.length] != pngSignature) return PngHeaderResult(PngError.invalid, "Png header missing");

    file = file[PNG_SIGNATURE.length..$];

    immutable chunkHeader = loadChunkHeader(file);
    if (!chunkHeader)
        return PngHeaderResult(chunkHeader.error, chunkHeader.message);

    if (chunkHeader.value.type != HEADER_CHUNK_TYPE)
        return PngHeaderResult(PngError.invalid, "Png file doesn't start with the header chunk");

    if (chunkHeader.value.length != PngHeaderData.sizeof) 
        return PngHeaderResult(PngError.invalid, "Invalid header chunk length");

    auto result = PngHeaderResult(*cast(PngHeaderData*)file.ptr);
    if (result.value.colorType > PngColorType.max || pngColorTypeToSamples[result.value.colorType] == 0)
        return PngHeaderResult(PngError.invalid, "Invalid color type found");

    immutable bd = result.value.bitDepth;
    if (bd != 1 && bd != 2 && bd != 4 && bd != 8 && bd != 16)
    {
        return PngHeaderResult(PngError.invalid, "Invalid bit depth found");
    }
    import std.bitmanip : swapEndian;
    result.value.width = result.value.width.swapEndian;
    result.value.height = result.value.height.swapEndian;

    return result;
}

/// Loads the given byte array as Png image into an ImageBuffer
ImageBuffer loadPng(const ubyte[] file)
{
    PngChunk* chunks;
    return loadPng(file, getGcAllocator(), null, chunks).unwrap;
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
ImageBuffer loadPng(const ubyte[] file, out PngChunk* chunks)
{
    return loadPng(file, getGcAllocator(), getGcAllocator(), chunks).unwrap;
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
    import core.lifetime : move;

    auto pngHeader = loadPngHeader(file);
    if (!pngHeader)
        return ImageResult(pngHeader.error, pngHeader.message);

    auto loader = PngLoadData(file, pngHeader.value, allocator, chunkAllocator);

    loader.loadPngChunks();

    if (loader.error)
        return ImageResult(PngError.failure, loader.error);

    return ImageResult(loader.result.move);
}

// Structures that holds all the data needed during decoding of PNG and contains operations that does the decoding
private struct PngLoadData
{
    PngHeaderData info;
    alias info this;

    const(ubyte)[] data; // raw data
    PngPaletteEntry[] palette;
    // We want to have a full size transparency buffer even when actual transparency chunk is shorter
    // to simplify algorithm for moving it to alpha channel.
    ubyte[256] transparency;
    int transLength;
    Allocator* allocator;
    Allocator* chunkAllocator;
    PngChunk* chunks;
    ubyte[] pixels; // decoded pixels
    ubyte[] pixelBuffer; // pointer into pixels where current non final data resides
    int lineBytes;
    uint gamma;
    Chromaticities chromaticities;
    bool isSRGB;
    ImageBuffer result;
    string error;

    this(const(ubyte)[] file, const PngHeaderData header, Allocator* a, Allocator* ca) nothrow @nogc
    {
        data = file[PNG_SIGNATURE.length..$];
        info = header;
        allocator = a;
        chunkAllocator = ca;

        lineBytes = (bitDepth * pngColorTypeToSamples[colorType] * width + 7) / 8;

        result.width = width;
        result.height = height;
    }

    private bool setupZlibStream(ref z_stream zStream, void* zlibAllocator) nothrow @nogc
    {
        import etc.c.zlib : Z_OK;
        if (inflateInit(&zStream) != Z_OK)
            return withError("Failed to initialize zlib for Png extraction");

        auto targeBitDepth = bitDepth;
        auto targetSamples = pngColorTypeToSamples[colorType];
        if (colorType == PngColorType.paletteColor)
        {
            targeBitDepth = 8;
            targetSamples = 3;
        }
        if (transLength > 0) targetSamples++;
        result.rowPitch = (targeBitDepth * targetSamples * width + 7) / 8;

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

        auto pixelBytes = result.rowPitch * height;
        if (pixelBytes < zStream.avail_out) pixelBytes = zStream.avail_out;
        pixels = cast(ubyte[])allocator.allocate(pixelBytes);
        if (pixels.length != pixelBytes) return withError(allocationErrorMessage);

        pixelBuffer = pixels[pixelBytes - zStream.avail_out..$];
        zStream.next_out = pixelBuffer.ptr;
        zStream.zalloc = &zallocFunc;
        zStream.zfree = &zfreeFunc;
        zStream.opaque = zlibAllocator;
        return true;
    }

    private bool loadPngChunks() nothrow @nogc
    {
        bool headerAddedToMeta = false;
        bool dataFound = false;
        bool unzipDone = false;

        ZlibStackAllocator zlibAllocator;
        z_stream zStream;

        while (true)
        {
            auto chunkHeader = loadChunkHeader(data);
            if (!chunkHeader)
                return withError(chunkHeader.message);

            switch (chunkHeader.value.type)
            {
                case HEADER_CHUNK_TYPE:
                    if (headerAddedToMeta) return withError("Duplicate Header chunk found");
                    headerAddedToMeta = true;
                    goto default;

                case DATA_CHUNK_TYPE:
                    import etc.c.zlib : Z_OK, Z_STREAM_END, Z_NO_FLUSH;
                    if (!dataFound)
                    {
                        if (!setupZlibStream(zStream, &zlibAllocator))
                            return false;
                    }
                    dataFound = true;
                    zStream.avail_in = chunkHeader.value.length;
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
                    if (dataFound) return withError("Found transparency chunk after data chunk");
                    if (transLength > 0) return withError("Second transparency chunk encountered");
                    if (colorType == PngColorType.paletteColor && chunkHeader.value.length > (1 << bitDepth))
                    {
                        return withError("Transparency chunk too long");
                    }
                    transLength = chunkHeader.value.length;
                    transparency[0..transLength] = data[0..transLength];
                    transparency[transLength..$] = 0xff;
                    goto default;
                
                case PALETTE_CHUNK_TYPE:
                    if (dataFound) return withError("Found palette chunk after data chunk");
                    if (transLength > 0) return withError("Found palette chunk after transparency chunk");
                    if (palette.length > 0) return withError("Second palette chunk encountered");
                    if (colorType != PngColorType.paletteColor &&
                        colorType != PngColorType.rgbColor &&
                        colorType != PngColorType.rgbaColor)
                    {
                        return withError("Palette found in grayscale image");
                    }
                    if (chunkHeader.value.length > (1 << bitDepth) * PngPaletteEntry.sizeof)
                        return withError("Palette chunk length invalid");
                    palette = data[0..chunkHeader.value.length].asArrayOf!PngPaletteEntry;
                    goto default;
                
                case GAMMA_CHUNK_TYPE:
                    import std.bitmanip: swapEndian;
                    gamma = *cast(uint*)data.ptr;
                    gamma = gamma.swapEndian;
                    goto default;

                case CHROMATICITIES_CHUNK_TYPE:
                    import std.bitmanip: swapEndian;
                    chromaticities = *cast(Chromaticities*)data.ptr;
                    chromaticities.whiteX = chromaticities.whiteX.swapEndian;
                    chromaticities.whiteY = chromaticities.whiteY.swapEndian;
                    chromaticities.redX = chromaticities.redX.swapEndian;
                    chromaticities.redY = chromaticities.redY.swapEndian;
                    chromaticities.greenX = chromaticities.greenX.swapEndian;
                    chromaticities.greenY = chromaticities.greenY.swapEndian;
                    chromaticities.blueX = chromaticities.blueX.swapEndian;
                    chromaticities.blueY = chromaticities.blueY.swapEndian;
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
                        auto inputData = pixelBuffer;
                        auto output = pixelBuffer;
                        immutable isFinalFormat = transLength == 0 &&
                                (colorType == PngColorType.grayscale || colorType == PngColorType.rgbColor) ||
                                colorType == PngColorType.grayscaleWithAlpha || colorType == PngColorType.rgbaColor;

                        // For final formats there are no additional operations so we need to put defiltered
                        // pixels into their final position
                        if (isFinalFormat) output = pixels;
                        if (!defilter(inputData, output, lineBytes, height)) return false;
                        if (!isFinalFormat) moveFilteredDataToTheEnd();
                    }
                    if (!setupFormat()) return false;
                    return true;

                default:
                    if (chunkAllocator == null) break;
                    auto chunkMemory = chunkAllocator.allocate(PngChunk.sizeof + chunkHeader.value.length).asArrayOf!ubyte;
                    if (chunkMemory.length != PngChunk.sizeof + chunkHeader.value.length)
                    {
                        return withError("Allocation from the given chunk allocator failed");
                    }
                    auto mdata = cast(PngChunk*)chunkMemory.ptr;
                    mdata.type[] = chunkHeader.value.type[];
                    mdata.data = chunkMemory[PngChunk.sizeof..$];
                    mdata.next = chunks;
                    mdata.data[] = data[0..chunkHeader.value.length];
                    chunks = mdata;
                    break;
            }

            data = data[(chunkHeader.value.length + crcSize)..$];
        }
        return false;
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
        auto inputData = pixelBuffer;
        auto output = pixelBuffer;
        foreach (i, passWidth; passWidths)
        {
            if (passWidth == 0 || passHeights[i] == 0) continue;
            if (!defilter(inputData, output, (passWidth * sampleBits + 7) / 8, passHeights[i])) return false;
        }

        // If defiltering didn't fail allocate space for deinterlaced image and setup deallocation of old pixel data at the end
        immutable pixelBytes = result.rowPitch * height;
        auto newPixels = cast(ubyte[])allocator.allocate(pixelBytes);
        if (newPixels.length != pixelBytes) return withError(allocationErrorMessage);
        ubyte[] newPixelBuffer;
        if (colorType == PngColorType.grayscaleWithAlpha || colorType == PngColorType.rgbaColor)
            newPixelBuffer = newPixels;
        else
            newPixelBuffer = newPixels[pixelBytes - lineBytes * height..$];
        scope (exit)
        {
            auto toDeallocate = pixels;
            pixels = newPixels;
            pixelBuffer = newPixelBuffer;
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
                        newPixelBuffer[newPos..newPos + bytesPerPixel] = pixelBuffer[i..i + bytesPerPixel];
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
                        newPixelBuffer[newPos..newPos + bytesPerPixel] = pixelBuffer[i..i + bytesPerPixel];
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
                        newPixelBuffer[newPos..newPos + bytesPerPixel] = pixelBuffer[i..i + bytesPerPixel];
                        i += bytesPerPixel;
                    }
                }
            }
            // Pass 7
            for (int y = 1; y < height; y += 2)
            {
                immutable newPos = y * lineBytes;
                newPixelBuffer[newPos..newPos + lineBytes] = pixelBuffer[i..i + lineBytes];
                i += lineBytes;
            }
        }
        else // if (bitDepth < 8)
        {
            import core.bitop: ror;
            int i = 0; // Counter over bytes
            int ic = 0; // Counter over bits
            immutable lineBits = sampleBits * width;
            immutable ubyte andMask = cast(ubyte)((1 << bitDepth) - 1);
            immutable ubyte startShift = cast(ubyte)(8 - bitDepth);
            immutable ubyte startMask = cast(ubyte)(andMask << startShift);
            // Pass 1 and 2
            for (int pass = 0; pass < 2; pass++)
            {
                immutable startx = pass * 4 * bitDepth;
                immutable xinc = bitDepth * 8;
                immutable newBitShift = (24 - (pass * 4 + 1) * bitDepth) % 8;
                for (int y = 0; y < height; y += 8)
                {
                    ubyte shift = startShift;
                    ubyte mask = startMask;
                    immutable linePos = y * lineBytes;
                    for (int bitx = startx; bitx < lineBits; bitx += xinc)
                    {
                        immutable x = bitx / 8;
                        newPixelBuffer[linePos + x] |= cast(ubyte)((((pixelBuffer[i] & mask) >> shift) & andMask) << newBitShift);
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
                immutable startx = pass * 2 * bitDepth;
                immutable xinc = bitDepth * 4;
                immutable starty = (1 - pass) * 4;
                int[2] newBitShifts;
                newBitShifts[0] = (16 - (pass * 2 + 1) * bitDepth) % 8;
                newBitShifts[1] = bitDepth == 1 ? newBitShifts[0] - 4 : newBitShifts[0];
                immutable yinc = pass == 0 ? 8 : 4;
                for (int y = starty; y < height; y += yinc)
                {
                    ubyte shift = startShift;
                    ubyte mask = startMask;
                    immutable linePos = y * lineBytes;
                    auto bitShiftIndex = 0;
                    for (int bitx = startx; bitx < lineBits; bitx += xinc)
                    {
                        immutable x = bitx / 8;
                        immutable newBitShift = newBitShifts[bitShiftIndex];
                        bitShiftIndex = 1 - bitShiftIndex;
                        newPixelBuffer[linePos + x] |= (((pixelBuffer[i] & mask) >> shift) & andMask) << newBitShift;
                        shift = (shift + 8 - bitDepth) & 0x7;
                        mask = ror(mask, cast(uint)bitDepth);
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
                immutable startx = pass * bitDepth;
                immutable xinc = bitDepth * 2;
                immutable starty = 2 - pass * 2;
                immutable yinc = 4 - pass * 2;
                immutable shiftOffset = 8 - 2 * bitDepth;
                int[4] newBitShifts;
                newBitShifts[0] = 8 - (pass + 1) * bitDepth;
                newBitShifts[1] = (newBitShifts[0] + shiftOffset) % 8;
                newBitShifts[2] = (newBitShifts[1] + shiftOffset) % 8;
                newBitShifts[3] = (newBitShifts[2] + shiftOffset) % 8;
                for (int y = starty; y < height; y += yinc)
                {
                    ubyte shift = startShift;
                    ubyte mask = startMask;
                    immutable linePos = y * lineBytes;
                    auto bitShiftIndex = 0;
                    for (int bitx = startx; bitx < lineBits; bitx += xinc)
                    {
                        immutable x = bitx / 8;
                        immutable newBitShift = newBitShifts[bitShiftIndex];
                        bitShiftIndex = (bitShiftIndex + 1) % 4;
                        newPixelBuffer[linePos + x] |= (((pixelBuffer[i] & mask) >> shift) & andMask) << newBitShift;
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
                newPixelBuffer[linePos..linePos + lineBytes] = pixelBuffer[i..i + lineBytes];
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

    private void moveGrayscaleTransparencyToAlpha() nothrow @nogc
    {
        immutable newLineBytes = (bitDepth * 2 * width + 7) / 8;
        auto output = pixels;
        auto input = pixelBuffer;

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
    }

    private bool depalettize() nothrow @nogc
    {
        immutable pixelSize = transLength > 0 ? 4 : 3;
        immutable newLineBytes = pixelSize * width;
        auto output = pixels;
        auto input = pixelBuffer;

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
                    if (index >= palette.length) return withError("Invalid palette index found");
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

        return true;
    }

    private void moveRgbTransparencyToAlpha() nothrow @nogc
    {
        immutable newLineBytes = bitDepth * 4 * width / 8;
        auto output = pixels;
        auto input = pixelBuffer;

        immutable int samples = width * 3;

        if (bitDepth == 16)
        {
            auto input16 = input.asArrayOf!ushort;
            auto output16 = output.asArrayOf!ushort;
            const transparency16 = transparency.asArrayOf!ushort;
            foreach (y; 0..height)
            {
                int writePos = 0;
                int x = 0;
                while (x < samples)
                {
                    output16[writePos++] = input16[x++];
                    output16[writePos++] = input16[x++];
                    output16[writePos++] = input16[x++];
                    if (output16[writePos - 3..writePos] == transparency16[0..3]) output16[writePos++] = 0;
                    else output16[writePos++] = 0xffff;
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
                    if (output[writePos - 3..writePos] == transparency[0..3]) output[writePos++] = 0;
                    else output[writePos++] = 0xff;
                    x += 3;
                }
                output = output[newLineBytes..$];
                input = input[lineBytes..$];
            }
        }
    }

    private void moveFilteredDataToTheEnd() nothrow @nogc
    {
        immutable bufferLength = lineBytes * height;
        if (bufferLength == pixelBuffer.length) return;
        auto diff = pixelBuffer.length - bufferLength;
        foreach_reverse (i; 0..bufferLength)
        {
            pixelBuffer[i + diff] = pixelBuffer[i];
        }
        pixelBuffer = pixelBuffer[diff..$];
    }

    private bool setupFormat() nothrow @nogc
    {
        static string getGrayscaleFormat(ubyte bitDepth, bool hasAlpha)
        {
            final switch (bitDepth)
            {
                case 1: return hasAlpha ? "la_1_1" : "l_1";
                case 2: return hasAlpha ? "la_2_2" : "l_2";
                case 4: return hasAlpha ? "la_4_4" : "l_4";
                case 8: return hasAlpha ? "la" : "l";
                case 16: return hasAlpha ? "la_16_16" : "l_16";
            }
        }

        static string getRgbFormat(ubyte bitDepth, bool hasAlpha)
        {
            final switch (bitDepth)
            {
                case 8: return hasAlpha ? "rgba" : "rgb";
                case 16: return hasAlpha ? "rgba_16_16_16_16" : "rgb_16_16_16";
            }
        }

        result.blockWidth = 1;
        result.blockHeight = 1;
        result.bitsPerBlock = 8;
        string strFormat;
        import core.bitop: bsf;
        final switch (colorType)
        {
            case PngColorType.grayscale:
                if (transLength > 0)
                {
                    moveGrayscaleTransparencyToAlpha();
                    goto case PngColorType.grayscaleWithAlpha;
                }
                if (bitDepth < 8) result.blockWidth = 8 / bitDepth;
                else result.bitsPerBlock = bitDepth;
                strFormat = getGrayscaleFormat(bitDepth, false);
                break;
            case PngColorType.grayscaleWithAlpha:
                if (bitDepth < 4) result.blockWidth = 4 / bitDepth;
                else result.bitsPerBlock = cast(ubyte)(2 * bitDepth);
                strFormat = getGrayscaleFormat(bitDepth, true);
                break;
            case PngColorType.paletteColor:
                if (!depalettize()) return false;
                result.bitsPerBlock = transLength > 0 ? 32 : 24;
                strFormat = getRgbFormat(8, transLength > 0);
                break;
            case PngColorType.rgbColor:
                if (transLength > 0)
                {
                    moveRgbTransparencyToAlpha();
                    goto case PngColorType.rgbaColor;
                }
                result.bitsPerBlock = bitDepth == 8 ? 24 : 48;
                strFormat = getRgbFormat(bitDepth, false);
                break;
            case PngColorType.rgbaColor:
                result.bitsPerBlock = bitDepth == 8 ? 32 : 64;
                strFormat = getRgbFormat(bitDepth, true);
                break;
        }

        enum string rgbFormatTemplate = "R{0.00000, 0.00000, 0.00000}G{0.00000, 0.00000, 0.00000}B{0.00000, 0.00000, 0.00000}";
        enum string rgbwFormatTemplate = "R{0.00000, 0.00000, 0.00000}G{0.00000, 0.00000, 0.00000}B{0.00000, 0.00000, 0.00000}@{0.00000, 0.00000}";

        char[rgbwFormatTemplate.length] formatBuffer = rgbwFormatTemplate;
        char[] chrFormat;

        enum string gammaFormatTemplate = "^0.00000";
        char[gammaFormatTemplate.length] gammaBuffer = gammaFormatTemplate;
        char[] gammaFormat;

        if (!isSRGB)
        {
            if (chromaticities.isSet)
            {
                import wg.color.xyz : xyY;
                import wg.color.rgb.colorspace: rgbColorSpaceName;

                immutable xw = chromaticities.whiteX / 100_000f;
                immutable yw = chromaticities.whiteY / 100_000f;
                immutable xr = chromaticities.redX / 100_000f;
                immutable yr = chromaticities.redY / 100_000f;
                immutable xg = chromaticities.greenX / 100_000f;
                immutable yg = chromaticities.greenY / 100_000f;
                immutable xb = chromaticities.blueX / 100_000f;
                immutable yb = chromaticities.blueY / 100_000f;
                auto white = xyY(xw, yw, 1f);

                const(char)[] colorSpaceName = rgbColorSpaceName(white, xr, yr, xg, yg, xb, yb);

                if (colorSpaceName.length)
                {
                    if (colorSpaceName == "sRGB") chrFormat = [];
                    else
                    {
                        chrFormat = formatBuffer[0..colorSpaceName.length];
                        chrFormat[] = colorSpaceName[];
                    }
                }
                else
                {
                    chrFormat = formatBuffer[];

                    // libpng tries to explain how to calculate Y from given chromacities here:
                    // https://github.com/glennrp/libpng/blob/libpng16/png.c#L1295
                    // I couldn't understand :) it so I devised my own formulas...

                    immutable c0 = xb / yb;
                    immutable c1 = c0 - xr / yr;
                    immutable c2 = c0 - xg / yg;
                    immutable c3 = c0 - xw / yw;

                    immutable d0 = (1 - xb) / yb;
                    immutable d1 = d0 - (1 - xr) / yr;
                    immutable d2 = d0 - (1 - xg) / yg;
                    immutable d3 = d0 - (1 - xw) / yw;

                    immutable Yr = (c3 * d2 - c2 * d3) / (c1 * d2 - c2 * d1);
                    immutable Yg = (c3 - c1 * Yr) / c2;
                    immutable Yb = 1f - Yr - Yg;

                    int wp;
                    if (chromaticities.isWhiteSet()) {
                        import wg.color.standard_illuminant: standardIlluminantName;
                        auto strWhitepoint = standardIlluminantName(white);
                        if (strWhitepoint)
                        {
                            chrFormat = formatBuffer[0..rgbFormatTemplate.length + strWhitepoint.length + 2];
                            chrFormat[$ - strWhitepoint.length - 1 .. $ - 1] = strWhitepoint[];
                        }
                        else
                        {
                            auto wx = chromaticities.whiteX;
                            auto wy = chromaticities.whiteY;
                            wp = rgbwFormatTemplate.length - 2;
                            foreach(i; 0..5)
                            {
                                chrFormat[wp--] = '0' + wy % 10;
                                wy = wy / 10;
                            }
                            chrFormat[wp - 1] = '0' + wy % 10;
                            wp -= ", 0.".length;
                            foreach(i; 0..5)
                            {
                                chrFormat[wp--] = '0' + wx % 10;
                                wx /= 10;
                            }
                        }
                    }
                    else
                    {
                        chrFormat = formatBuffer[0..rgbFormatTemplate.length];
                    }
                    wp = rgbFormatTemplate.length - 2;
                    uint[3][3] xys = [[chromaticities.redX, chromaticities.redY, cast(uint)(Yr * 100_000)],
                                      [chromaticities.greenX, chromaticities.greenY, cast(uint)(Yg * 100_000)],
                                      [chromaticities.blueX, chromaticities.blueY, cast(uint)(Yb * 100_000)]];
                    foreach_reverse (y; 0..3)
                    {
                        foreach_reverse (x; 0..3)
                        {
                            auto xy = xys[y][x];
                            foreach (i; 0..5)
                            {
                                chrFormat[wp--] = '0' + xy % 10;
                                xy /= 10;
                            }
                            chrFormat[wp - 1] = '0' + xy % 10;
                            wp -= 4;
                        }
                        wp -= 1;
                    }
                }
            }
            if (gamma != 0 && gamma != 45_455) // standard sRGB gamma
            {
                gammaFormat = gammaBuffer[];
                if (gamma == 100_000) 
                {
                    gammaFormat = gammaBuffer[0..2];
                    gammaFormat[1] = '1';
                }
                else
                {
                    uint g = cast(uint)(10_000_000_000L / gamma);
                    auto wp = gammaFormat.length - 1;
                    foreach(i; 0..5)
                    {
                        gammaFormat[wp--] = '0' + g % 10;
                        g /= 10;
                    }
                    gammaFormat[1] = '0' + g % 10;
                }
            }
        }

        auto totalFormatLength = strFormat.length + chrFormat.length + gammaFormat.length;

        if (totalFormatLength > strFormat.length)
        {
            // Plus 2 for one '_' char and zero terminator at the end of the string
            char[] finalFormat = cast(char[])allocator.allocate(totalFormatLength + 2);
            auto formatPart = finalFormat;
            formatPart[0..strFormat.length] = strFormat[];
            formatPart[strFormat.length] = '_';
            formatPart = formatPart[strFormat.length + 1..$];
            formatPart[0..chrFormat.length] = chrFormat[];
            formatPart = formatPart[chrFormat.length..$];
            formatPart[0..gammaFormat.length] = gammaFormat[];
            formatPart[$ - 1] = '\0';
            result.pixelFormat = finalFormat.ptr;
        }
        else result.pixelFormat = strFormat.ptr;

        result.data = pixels.ptr;
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

private alias PngChunkResult = Result!(PngChunkHeader, PngError);
private PngChunkResult loadChunkHeader(ref const(ubyte)[] file) nothrow @nogc
{
    if (file.length < PngChunkHeader.sizeof)
        return PngChunkResult(PngError.corrupt, "End of file reached too soon");
    auto chunkHeader = *cast(PngChunkHeader*)file.ptr;
    import std.bitmanip : swapEndian;
    chunkHeader.length = chunkHeader.length.swapEndian;

    if (file.length < PngChunkHeader.sizeof + chunkHeader.length + crcSize)
        return PngChunkResult(PngError.corrupt, "File size and chunk size mismatch");

    {
        import std.digest.crc : crc32Of;
        import std.algorithm: reverse;
        auto crcPart = file[4..chunkHeader.length + 8];
        auto crc = crc32Of(crcPart);
        immutable crcStart = PngChunkHeader.sizeof + chunkHeader.length;
        auto const actualCrc = file[crcStart..crcStart + 4];
        if (crc[].reverse != actualCrc) 
            return PngChunkResult(PngError.corrupt, "CRC check failed");
    }

    file = file[PngChunkHeader.sizeof..$];
    return PngChunkResult(chunkHeader);
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


private:

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

private struct ZlibStackAllocator
{
    ubyte[zlibInflateMemory] zlibBuffer;
    uint zlibBufferUsed;

    void* allocate(uint size) nothrow @nogc
    {
        immutable newUsed = zlibBufferUsed + size;
        if (newUsed > zlibBuffer.length) return null;
        auto result = &zlibBuffer[zlibBufferUsed];
        zlibBufferUsed = newUsed;
        return result;
    }
}

private extern(C) void* zallocFunc(void* opaque, uint items, uint size) nothrow @nogc
{
    auto allocator = cast(ZlibStackAllocator*)opaque;
    return allocator.allocate(items * size);
}

private extern(C) void zfreeFunc(void* opaque, void* address) nothrow @nogc
{
    // No need to do anything since the whole memory will be freed at the end of the process
}
