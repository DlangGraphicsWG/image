module wg.image.transform;

import wg.image;
import wg.image.imagebuffer;

enum isImageBuffer(T) = is(T == ImageBuffer) || is(T == Image!U, U);

// it's possible to do certain loss-less and opaque transforms on images

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

Image stripMetadata(Image)(ref Image image) if (isImageBuffer!Image)
{
    Image r = image;
    r.metadata = null;
    return r;
}

// TODO: flip (in-place support?)
// TODO: flip (not in-place, buffer)
// TODO: rotation (requires destination image buffer, with matching format)
