module test.main;

import wg.image;
import wg.image.transform;
import wg.color;
import wg.format.png;

/// Tests the loading of all images from png test suite that can be downloaded from http://www.schaik.com/pngsuite/
void testPngLoad()
{
    import std.stdio : writefln, write;
    import std.file: read, dirEntries, SpanMode, writeFile = write;
    import std.algorithm: filter, endsWith, sort;
    import std.array: array;
    import std.datetime.stopwatch: StopWatch, AutoStart;

    auto sw = StopWatch(AutoStart.yes);

    // Download the png suite images from http://www.schaik.com/pngsuite/ and put the path to them bellow
    string path = "/path/to/PngSuite-2017jul19/";
    auto pngFiles = dirEntries(path, SpanMode.shallow, false)
        .filter!(f => f.name.endsWith(".png")).array().sort();
    foreach(string fname; pngFiles)
    {
        // Uncomment the next line and comment the foreach line above to just test loading of one specific image
        //auto fname = "/path/to/PngSuite-2017jul19/specificImage.png";
        auto file = cast(ubyte[])read(fname);
        write("Loading ", fname);
        sw.reset();
        auto p = loadPng(file);
        import wg.util.util: asDString;
        writefln(": loaded with status: '%s' in %sμs format: %s", p.error ? p.error : "OK", sw.peek().total!("usecs"), p.pixelFormat.asDString);

        import wg.format.bmp : writeBMP;
        if (p.error is null) 
        {
            // BMP writer might not support all the formats that Png loader might return so you might want
            // to just write the row pixels by uncommenting the next line
            //writeFile(fname ~ ".data", p.data[0..p.rowPitch * p.height]);
            auto bmpData = writeBMP(p);
            if (bmpData.length > 0) writeFile(fname ~ ".bmp", bmpData);
        }
    }
}

int main()
{
    // TODO: do something...

    RGB8[4] tinyImage = [Colors.red, Colors.green, Colors.blue, Colors.yellow];
    Image!RGB8 thing = tinyImage.asImage(2, 2);

    thing = thing.crop(1, 2, 1, 2);

    //testPngLoad();

    return 0;
}