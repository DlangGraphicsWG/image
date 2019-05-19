// Written in the D programming language.
/**
RGB color space.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.color;

import wg.color.rgb;

/// 24 bit RGB color type with 8 bits per channel.
alias RGB8 = RGB!("rgb");
/// 32 bit RGB color type with 8 bits per channel.
alias RGBX8 = RGB!("rgbx");
/// 32 bit RGB + alpha color type with 8 bits per channel.
alias RGBA8 = RGB!("rgba");

/// Floating point RGB color type.
alias RGBf32 = RGB!("rgb_f32_f32_f32");
/// Floating point RGB + alpha color type.
alias RGBAf32 = RGB!("rgba_f32_f32_f32_f32");


/// Set of colors defined by X11, adopted by the W3C, SVG, and other popular libraries.
enum Colors
{
    aliceBlue            = RGB8(240,248,255), /// <font color=aliceBlue>&#x25FC;</font>
    antiqueWhite         = RGB8(250,235,215), /// <font color=antiqueWhite>&#x25FC;</font>
    aqua                 = RGB8(0,255,255),   /// <font color=aqua>&#x25FC;</font>
    aquamarine           = RGB8(127,255,212), /// <font color=aquamarine>&#x25FC;</font>
    azure                = RGB8(240,255,255), /// <font color=azure>&#x25FC;</font>
    beige                = RGB8(245,245,220), /// <font color=beige>&#x25FC;</font>
    bisque               = RGB8(255,228,196), /// <font color=bisque>&#x25FC;</font>
    black                = RGB8(0,0,0),       /// <font color=black>&#x25FC;</font>
    blanchedAlmond       = RGB8(255,235,205), /// <font color=blanchedAlmond>&#x25FC;</font>
    blue                 = RGB8(0,0,255),     /// <font color=blue>&#x25FC;</font>
    blueViolet           = RGB8(138,43,226),  /// <font color=blueViolet>&#x25FC;</font>
    brown                = RGB8(165,42,42),   /// <font color=brown>&#x25FC;</font>
    burlyWood            = RGB8(222,184,135), /// <font color=burlyWood>&#x25FC;</font>
    cadetBlue            = RGB8(95,158,160),  /// <font color=cadetBlue>&#x25FC;</font>
    chartreuse           = RGB8(127,255,0),   /// <font color=chartreuse>&#x25FC;</font>
    chocolate            = RGB8(210,105,30),  /// <font color=chocolate>&#x25FC;</font>
    coral                = RGB8(255,127,80),  /// <font color=coral>&#x25FC;</font>
    cornflowerBlue       = RGB8(100,149,237), /// <font color=cornflowerBlue>&#x25FC;</font>
    cornsilk             = RGB8(255,248,220), /// <font color=cornsilk>&#x25FC;</font>
    crimson              = RGB8(220,20,60),   /// <font color=crimson>&#x25FC;</font>
    cyan                 = RGB8(0,255,255),   /// <font color=cyan>&#x25FC;</font>
    darkBlue             = RGB8(0,0,139),     /// <font color=darkBlue>&#x25FC;</font>
    darkCyan             = RGB8(0,139,139),   /// <font color=darkCyan>&#x25FC;</font>
    darkGoldenrod        = RGB8(184,134,11),  /// <font color=darkGoldenrod>&#x25FC;</font>
    darkGray             = RGB8(169,169,169), /// <font color=darkGray>&#x25FC;</font>
    darkGrey             = RGB8(169,169,169), /// <font color=darkGrey>&#x25FC;</font>
    darkGreen            = RGB8(0,100,0),     /// <font color=darkGreen>&#x25FC;</font>
    darkKhaki            = RGB8(189,183,107), /// <font color=darkKhaki>&#x25FC;</font>
    darkMagenta          = RGB8(139,0,139),   /// <font color=darkMagenta>&#x25FC;</font>
    darkOliveGreen       = RGB8(85,107,47),   /// <font color=darkOliveGreen>&#x25FC;</font>
    darkOrange           = RGB8(255,140,0),   /// <font color=darkOrange>&#x25FC;</font>
    darkOrchid           = RGB8(153,50,204),  /// <font color=darkOrchid>&#x25FC;</font>
    darkRed              = RGB8(139,0,0),     /// <font color=darkRed>&#x25FC;</font>
    darkSalmon           = RGB8(233,150,122), /// <font color=darkSalmon>&#x25FC;</font>
    darkSeaGreen         = RGB8(143,188,143), /// <font color=darkSeaGreen>&#x25FC;</font>
    darkSlateBlue        = RGB8(72,61,139),   /// <font color=darkSlateBlue>&#x25FC;</font>
    darkSlateGray        = RGB8(47,79,79),    /// <font color=darkSlateGray>&#x25FC;</font>
    darkSlateGrey        = RGB8(47,79,79),    /// <font color=darkSlateGrey>&#x25FC;</font>
    darkTurquoise        = RGB8(0,206,209),   /// <font color=darkTurquoise>&#x25FC;</font>
    darkViolet           = RGB8(148,0,211),   /// <font color=darkViolet>&#x25FC;</font>
    deepPink             = RGB8(255,20,147),  /// <font color=deepPink>&#x25FC;</font>
    deepSkyBlue          = RGB8(0,191,255),   /// <font color=deepSkyBlue>&#x25FC;</font>
    dimGray              = RGB8(105,105,105), /// <font color=dimGray>&#x25FC;</font>
    dimGrey              = RGB8(105,105,105), /// <font color=dimGrey>&#x25FC;</font>
    dodgerBlue           = RGB8(30,144,255),  /// <font color=dodgerBlue>&#x25FC;</font>
    fireBrick            = RGB8(178,34,34),   /// <font color=fireBrick>&#x25FC;</font>
    floralWhite          = RGB8(255,250,240), /// <font color=floralWhite>&#x25FC;</font>
    forestGreen          = RGB8(34,139,34),   /// <font color=forestGreen>&#x25FC;</font>
    fuchsia              = RGB8(255,0,255),   /// <font color=fuchsia>&#x25FC;</font>
    gainsboro            = RGB8(220,220,220), /// <font color=gainsboro>&#x25FC;</font>
    ghostWhite           = RGB8(248,248,255), /// <font color=ghostWhite>&#x25FC;</font>
    gold                 = RGB8(255,215,0),   /// <font color=gold>&#x25FC;</font>
    goldenrod            = RGB8(218,165,32),  /// <font color=goldenrod>&#x25FC;</font>
    gray                 = RGB8(128,128,128), /// <font color=gray>&#x25FC;</font>
    grey                 = RGB8(128,128,128), /// <font color=grey>&#x25FC;</font>
    green                = RGB8(0,128,0),     /// <font color=green>&#x25FC;</font>
    greenYellow          = RGB8(173,255,47),  /// <font color=greenYellow>&#x25FC;</font>
    honeydew             = RGB8(240,255,240), /// <font color=honeydew>&#x25FC;</font>
    hotPink              = RGB8(255,105,180), /// <font color=hotPink>&#x25FC;</font>
    indianRed            = RGB8(205,92,92),   /// <font color=indianRed>&#x25FC;</font>
    indigo               = RGB8(75,0,130),    /// <font color=indigo>&#x25FC;</font>
    ivory                = RGB8(255,255,240), /// <font color=ivory>&#x25FC;</font>
    khaki                = RGB8(240,230,140), /// <font color=khaki>&#x25FC;</font>
    lavender             = RGB8(230,230,250), /// <font color=lavender>&#x25FC;</font>
    lavenderBlush        = RGB8(255,240,245), /// <font color=lavenderBlush>&#x25FC;</font>
    lawnGreen            = RGB8(124,252,0),   /// <font color=lawnGreen>&#x25FC;</font>
    lemonChiffon         = RGB8(255,250,205), /// <font color=lemonChiffon>&#x25FC;</font>
    lightBlue            = RGB8(173,216,230), /// <font color=lightBlue>&#x25FC;</font>
    lightCoral           = RGB8(240,128,128), /// <font color=lightCoral>&#x25FC;</font>
    lightCyan            = RGB8(224,255,255), /// <font color=lightCyan>&#x25FC;</font>
    lightGoldenrodYellow = RGB8(250,250,210), /// <font color=lightGoldenrodYellow>&#x25FC;</font>
    lightGray            = RGB8(211,211,211), /// <font color=lightGray>&#x25FC;</font>
    lightGrey            = RGB8(211,211,211), /// <font color=lightGrey>&#x25FC;</font>
    lightGreen           = RGB8(144,238,144), /// <font color=lightGreen>&#x25FC;</font>
    lightPink            = RGB8(255,182,193), /// <font color=lightPink>&#x25FC;</font>
    lightSalmon          = RGB8(255,160,122), /// <font color=lightSalmon>&#x25FC;</font>
    lightSeaGreen        = RGB8(32,178,170),  /// <font color=lightSeaGreen>&#x25FC;</font>
    lightSkyBlue         = RGB8(135,206,250), /// <font color=lightSkyBlue>&#x25FC;</font>
    lightSlateGray       = RGB8(119,136,153), /// <font color=lightSlateGray>&#x25FC;</font>
    lightSlateGrey       = RGB8(119,136,153), /// <font color=lightSlateGrey>&#x25FC;</font>
    lightSteelBlue       = RGB8(176,196,222), /// <font color=lightSteelBlue>&#x25FC;</font>
    lightYellow          = RGB8(255,255,224), /// <font color=lightYellow>&#x25FC;</font>
    lime                 = RGB8(0,255,0),     /// <font color=lime>&#x25FC;</font>
    limeGreen            = RGB8(50,205,50),   /// <font color=limeGreen>&#x25FC;</font>
    linen                = RGB8(250,240,230), /// <font color=linen>&#x25FC;</font>
    magenta              = RGB8(255,0,255),   /// <font color=magenta>&#x25FC;</font>
    maroon               = RGB8(128,0,0),     /// <font color=maroon>&#x25FC;</font>
    mediumAquamarine     = RGB8(102,205,170), /// <font color=mediumAquamarine>&#x25FC;</font>
    mediumBlue           = RGB8(0,0,205),     /// <font color=mediumBlue>&#x25FC;</font>
    mediumOrchid         = RGB8(186,85,211),  /// <font color=mediumOrchid>&#x25FC;</font>
    mediumPurple         = RGB8(147,112,219), /// <font color=mediumPurple>&#x25FC;</font>
    mediumSeaGreen       = RGB8(60,179,113),  /// <font color=mediumSeaGreen>&#x25FC;</font>
    mediumSlateBlue      = RGB8(123,104,238), /// <font color=mediumSlateBlue>&#x25FC;</font>
    mediumSpringGreen    = RGB8(0,250,154),   /// <font color=mediumSpringGreen>&#x25FC;</font>
    mediumTurquoise      = RGB8(72,209,204),  /// <font color=mediumTurquoise>&#x25FC;</font>
    mediumVioletRed      = RGB8(199,21,133),  /// <font color=mediumVioletRed>&#x25FC;</font>
    midnightBlue         = RGB8(25,25,112),   /// <font color=midnightBlue>&#x25FC;</font>
    mintCream            = RGB8(245,255,250), /// <font color=mintCream>&#x25FC;</font>
    mistyRose            = RGB8(255,228,225), /// <font color=mistyRose>&#x25FC;</font>
    moccasin             = RGB8(255,228,181), /// <font color=moccasin>&#x25FC;</font>
    navajoWhite          = RGB8(255,222,173), /// <font color=navajoWhite>&#x25FC;</font>
    navy                 = RGB8(0,0,128),     /// <font color=navy>&#x25FC;</font>
    oldLace              = RGB8(253,245,230), /// <font color=oldLace>&#x25FC;</font>
    olive                = RGB8(128,128,0),   /// <font color=olive>&#x25FC;</font>
    oliveDrab            = RGB8(107,142,35),  /// <font color=oliveDrab>&#x25FC;</font>
    orange               = RGB8(255,165,0),   /// <font color=orange>&#x25FC;</font>
    orangeRed            = RGB8(255,69,0),    /// <font color=orangeRed>&#x25FC;</font>
    orchid               = RGB8(218,112,214), /// <font color=orchid>&#x25FC;</font>
    paleGoldenrod        = RGB8(238,232,170), /// <font color=paleGoldenrod>&#x25FC;</font>
    paleGreen            = RGB8(152,251,152), /// <font color=paleGreen>&#x25FC;</font>
    paleTurquoise        = RGB8(175,238,238), /// <font color=paleTurquoise>&#x25FC;</font>
    paleVioletRed        = RGB8(219,112,147), /// <font color=paleVioletRed>&#x25FC;</font>
    papayaWhip           = RGB8(255,239,213), /// <font color=papayaWhip>&#x25FC;</font>
    peachPuff            = RGB8(255,218,185), /// <font color=peachPuff>&#x25FC;</font>
    peru                 = RGB8(205,133,63),  /// <font color=peru>&#x25FC;</font>
    pink                 = RGB8(255,192,203), /// <font color=pink>&#x25FC;</font>
    plum                 = RGB8(221,160,221), /// <font color=plum>&#x25FC;</font>
    powderBlue           = RGB8(176,224,230), /// <font color=powderBlue>&#x25FC;</font>
    purple               = RGB8(128,0,128),   /// <font color=purple>&#x25FC;</font>
    red                  = RGB8(255,0,0),     /// <font color=red>&#x25FC;</font>
    rosyBrown            = RGB8(188,143,143), /// <font color=rosyBrown>&#x25FC;</font>
    royalBlue            = RGB8(65,105,225),  /// <font color=royalBlue>&#x25FC;</font>
    saddleBrown          = RGB8(139,69,19),   /// <font color=saddleBrown>&#x25FC;</font>
    salmon               = RGB8(250,128,114), /// <font color=salmon>&#x25FC;</font>
    sandyBrown           = RGB8(244,164,96),  /// <font color=sandyBrown>&#x25FC;</font>
    seaGreen             = RGB8(46,139,87),   /// <font color=seaGreen>&#x25FC;</font>
    seashell             = RGB8(255,245,238), /// <font color=seashell>&#x25FC;</font>
    sienna               = RGB8(160,82,45),   /// <font color=sienna>&#x25FC;</font>
    silver               = RGB8(192,192,192), /// <font color=silver>&#x25FC;</font>
    skyBlue              = RGB8(135,206,235), /// <font color=skyBlue>&#x25FC;</font>
    slateBlue            = RGB8(106,90,205),  /// <font color=slateBlue>&#x25FC;</font>
    slateGray            = RGB8(112,128,144), /// <font color=slateGray>&#x25FC;</font>
    slateGrey            = RGB8(112,128,144), /// <font color=slateGrey>&#x25FC;</font>
    snow                 = RGB8(255,250,250), /// <font color=snow>&#x25FC;</font>
    springGreen          = RGB8(0,255,127),   /// <font color=springGreen>&#x25FC;</font>
    steelBlue            = RGB8(70,130,180),  /// <font color=steelBlue>&#x25FC;</font>
    tan                  = RGB8(210,180,140), /// <font color=tan>&#x25FC;</font>
    teal                 = RGB8(0,128,128),   /// <font color=teal>&#x25FC;</font>
    thistle              = RGB8(216,191,216), /// <font color=thistle>&#x25FC;</font>
    tomato               = RGB8(255,99,71),   /// <font color=tomato>&#x25FC;</font>
    turquoise            = RGB8(64,224,208),  /// <font color=turquoise>&#x25FC;</font>
    violet               = RGB8(238,130,238), /// <font color=violet>&#x25FC;</font>
    wheat                = RGB8(245,222,179), /// <font color=wheat>&#x25FC;</font>
    white                = RGB8(255,255,255), /// <font color=white>&#x25FC;</font>
    whiteSmoke           = RGB8(245,245,245), /// <font color=whiteSmoke>&#x25FC;</font>
    yellow               = RGB8(255,255,0),   /// <font color=yellow>&#x25FC;</font>
    yellowGreen          = RGB8(154,205,50)   /// <font color=yellowGreen>&#x25FC;</font>
}

/**
Convert between _color types.

Conversion is always supported between any pair of valid _color types.
Colour types usually implement only direct conversion between their immediate 'parent' _color type.
In the case of distantly related colors, convertColor will follow a conversion path via
 intermediate representations such that it is able to perform the conversion.

For instance, a conversion from HSV to Lab necessary follows the conversion path: HSV -> RGB -> XYZ -> Lab.

Params: color = A _color in some source format.
Returns: $(D_INLINECODE color) converted to the target format.
*/
To convertColor(To, From)(From color) @safe pure nothrow @nogc
{
    // cast along a conversion path to reach our target conversion
    alias Path = ConversionPath!(From, To);

    // no conversion is necessary
    static if (Path.length == 0)
        return color;
    else
    {
        import std.traits : moduleName;

        alias Target = Path[0];

        // this hack emulates ADL
        mixin("import " ~ moduleName!Target ~ " : destConvert = convertColorImpl;");
        static if (__traits(compiles, color.destConvert!Target()))
        {
            static if (Path.length > 1)
                return color.destConvert!Target().convertColor!To();
            else
                return color.destConvert!Target();
        }
        else
        {
            mixin("import " ~ moduleName!From ~ " : srcConvert = convertColorImpl;");
            static if (Path.length > 1)
                return color.srcConvert!Target().convertColor!To();
            else
                return color.srcConvert!Target();
        }
    }
}

///
unittest
{
    import wg.color;
    import wg.color.xyz;

    assert(RGBA8(0xFF, 0xFF, 0xFF, 0xFF).convertColor!xyY().convertColor!RGBA8() == RGBA8(0xFF, 0xFF, 0xFF, 0));
    assert(RGB8(0xFF, 0x80, 0x10).convertColor!RGBA8() == RGBA8(0xFF, 0x80, 0x10, 0x00));
}

/**
 * Create a color from a string.
 * Params: str = A string representation of a _color.$(BR)
 * May be a hex _color in the standard forms: (#/$)rgb/argb/rrggbb/aarrggbb$(BR)
 * May also be the name of any _color from the $(D_INLINECODE Colors) enum.
 * Returns: The _color expressed by the string.
 * Throws: Throws $(D_INLINECODE std.conv.ConvException) if the string is invalid.
 */
Color colorFromString(Color = RGBA8)(scope const(char)[] str) pure @safe
{
    import std.conv : ConvException;

    RGBA8 r;
    string error = colorFromStringImpl(str, r);
    if (error)
        throw new ConvException(error);
    return r.convertColor!Color;
}

///
unittest
{
    // common hex formats supported:

    // 3 digits
    assert(colorFromString!RGB8("F80") == RGB8(0xFF, 0x88, 0x00));
    assert(colorFromString!RGB8("#F80") == RGB8(0xFF, 0x88, 0x00));
    assert(colorFromString!RGB8("$F80") == RGB8(0xFF, 0x88, 0x00));

    // 6 digits
    assert(colorFromString!RGB8("FF8000") == RGB8(0xFF, 0x80, 0x00));
    assert(colorFromString!RGB8("#FF8000") == RGB8(0xFF, 0x80, 0x00));
    assert(colorFromString!RGB8("$FF8000") == RGB8(0xFF, 0x80, 0x00));

    // 4/8 digita (/w alpha)
    assert(colorFromString("#8C41") == RGBA8(0xCC, 0x44, 0x11, 0x88));
    assert(colorFromString("#80CC4401") == RGBA8(0xCC, 0x44, 0x01, 0x80));

    // named colors (case-insensitive)
    assert(colorFromString!RGB8("red") == RGB8(0xFF, 0x0, 0x0));
    assert(colorFromString!RGB8("WHITE") == RGB8(0xFF, 0xFF, 0xFF));
    assert(colorFromString!RGB8("LightGoldenrodYellow") == RGB8(250,250,210));

    // parse failure
    RGB8 c;
    assert(colorFromString("Ultraviolet", c) == false);
}

/**
 * Create a color from a string.
 * This version of the function is $(D_INLINECODE nothrow), $(D_INLINECODE @nogc).
 * Params: str = A string representation of a _color.$(BR)
 * May be a hex _color in the standard forms: (#/$)rgb/argb/rrggbb/aarrggbb$(BR)
 * May also be the name of any _color from the $(D_INLINECODE Colors) enum.
 * color = Receives the _color expressed by the string.
 * Returns: $(D_INLINECODE true) if a _color was successfully parsed from the string, $(D_INLINECODE false) otherwise.
 */
bool colorFromString(Color = RGBA8)(scope const(char)[] str, out Color color) pure nothrow @safe @nogc
{
    RGBA8 r;
    if (colorFromStringImpl(str, r) != null)
        return false;
    color = r.convertColor!Color;
    return true;
}

/// Parse a color from a string at compile time.
enum colorFromString(const(char)[] str, Color = RGBA8) = colorFromString!(Color)(str);


private:

import std.traits : TemplateOf, isInstanceOf;
import std.meta : AliasSeq;

template isSameKind(Ty1, Ty2)
{
    static if (is(TemplateOf!Ty1 == void))
        enum isSameKind = is(Ty1 == Ty2);
    else
        enum isSameKind = isInstanceOf!(TemplateOf!Ty1, Ty2);
}
template isParentType(Parent, Of)
{
    static if (!is(Of.ParentColor))
        enum isParentType = false;
    else static if (isSameKind!(Parent, Of.ParentColor))
        enum isParentType = true;
    else
        enum isParentType = isParentType!(Parent, Of.ParentColor);
}
template FindPath(From, To)
{
    static if (isSameKind!(To, From))
        alias FindPath = AliasSeq!(To);
    else static if (isParentType!(From, To))
        alias FindPath = AliasSeq!(FindPath!(From, To.ParentColor), To);
    else static if (is(From.ParentColor))
        alias FindPath = AliasSeq!(From, FindPath!(From.ParentColor, To));
    else
        static assert(false, "Shouldn't be here!");
}

// find the conversion path from one distant type to another
template ConversionPath(From, To)
{
    import wg.util.traits : Unqual;

    static if (is(Unqual!From == Unqual!To))
    {
        alias ConversionPath = AliasSeq!();
    }
    else
    {
        alias Path = FindPath!(Unqual!From, Unqual!To);
        static if (Path.length == 1 && !is(Path[0] == From))
            alias ConversionPath = Path;
        else
            alias ConversionPath = Path[1..$];
    }
}
unittest
{
    import wg.color;
    import wg.color.xyz;

    // test indirect conversion paths
    static assert(is(ConversionPath!(XYZ, XYZ) == AliasSeq!()));
    static assert(is(ConversionPath!(RGB8, RGB8) == AliasSeq!()));

    static assert(is(ConversionPath!(xyY, XYZ) == AliasSeq!(XYZ)));
    static assert(is(ConversionPath!(XYZ, xyY) == AliasSeq!(xyY)));

    static assert(is(ConversionPath!(RGB8, XYZ) == AliasSeq!(XYZ)));
    static assert(is(ConversionPath!(XYZ, RGBA8) == AliasSeq!(RGBA8)));
    static assert(is(ConversionPath!(RGB8, RGBA8) == AliasSeq!(RGBA8)));

    static assert(is(ConversionPath!(xyY, RGBA8) == AliasSeq!(XYZ, RGBA8)));
    static assert(is(ConversionPath!(RGB8, xyY) == AliasSeq!(XYZ, xyY)));

    // test attributes
    static assert(is(ConversionPath!(shared RGBA8, immutable xyY) == AliasSeq!(XYZ, xyY)));
}

string colorFromStringImpl(scope const(char)[] str, out RGBA8 color) pure nothrow @safe @nogc
{
    static const(char)[] getHex(return const(char)[] hex) pure nothrow @nogc @safe
    {
        if (hex.length > 0 && (hex[0] == '#' || hex[0] == '$'))
            hex = hex[1..$];
        foreach (i; 0 .. hex.length)
        {
            if (!(hex[i] >= '0' && hex[i] <= '9' || hex[i] >= 'a' && hex[i] <= 'f' || hex[i] >= 'A' && hex[i] <= 'F'))
                return null;
        }
        return hex;
    }

    const(char)[] hex = getHex(str);
    if (hex)
    {
        static ubyte val(char c) pure nothrow @nogc @safe
        {
            if (c >= '0' && c <= '9')
                return cast(ubyte)(c - '0');
            else if (c >= 'a' && c <= 'f')
                return cast(ubyte)(c - 'a' + 10);
            else
                return cast(ubyte)(c - 'A' + 10);
        }

        if (hex.length == 3)
        {
            ubyte r = val(hex[0]);
            ubyte g = val(hex[1]);
            ubyte b = val(hex[2]);
            color = RGBA8(cast(ubyte)(r | (r << 4)), cast(ubyte)(g | (g << 4)), cast(ubyte)(b | (b << 4)), 0xFF);
        }
        else if (hex.length == 4)
        {
            ubyte a = val(hex[0]);
            ubyte r = val(hex[1]);
            ubyte g = val(hex[2]);
            ubyte b = val(hex[3]);
            color = RGBA8(cast(ubyte)(r | (r << 4)), cast(ubyte)(g | (g << 4)), cast(ubyte)(b | (b << 4)), cast(ubyte)(a | (a << 4)));
        }
        else if (hex.length == 6)
        {
            ubyte r = cast(ubyte)(val(hex[0]) << 4) | val(hex[1]);
            ubyte g = cast(ubyte)(val(hex[2]) << 4) | val(hex[3]);
            ubyte b = cast(ubyte)(val(hex[4]) << 4) | val(hex[5]);
            color = RGBA8(r, g, b, 0xFF);
        }
        else if (hex.length == 8)
        {
            ubyte a = cast(ubyte)(val(hex[0]) << 4) | val(hex[1]);
            ubyte r = cast(ubyte)(val(hex[2]) << 4) | val(hex[3]);
            ubyte g = cast(ubyte)(val(hex[4]) << 4) | val(hex[5]);
            ubyte b = cast(ubyte)(val(hex[6]) << 4) | val(hex[7]);
            color = RGBA8(r, g, b, a);
        }
        else
            return "Invalid length for hex color";
        return null;
    }

    // need to write a string compare, since phobos is not nothrow @nogc, etc...
    static bool streqi(scope const(char)[] a, scope const(char)[] b)
    {
        if (a.length != b.length)
            return false;
        foreach(i; 0 .. a.length)
        {
            auto c1 = (a[i] >= 'A' && a[i] <= 'Z') ? a[i] | 0x20 : a[i];
            auto c2 = (b[i] >= 'A' && b[i] <= 'Z') ? b[i] | 0x20 : b[i];
            if(c1 != c2)
                return false;
        }
        return true;
    }

    static foreach (k; __traits(allMembers, Colors))
    {
        if (streqi(str, k))
        {
            mixin("enum Col = Colors." ~ k ~ ";");
            color = RGBA8(Col.r, Col.g, Col.b, 0xFF);
            return null;
        }
    }

    return "String is not a valid color";
}

shared static this()
{
    import wg.color.rgb : registerRGB;
    import wg.color.xyz : registerXYZ;

    registerXYZ();
    registerRGB();
}
