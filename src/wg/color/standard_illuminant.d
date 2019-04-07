// Written in the D programming language.
/**
Standard illuminants.

Authors:    Manu Evans
Copyright:  Copyright (c) 2019, Manu Evans.
License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/

module wg.color.standard_illuminant;

import wg.color.xyz : xyY;

/// The $(LINK2 https://en.wikipedia.org/wiki/Standard_illuminant, standard illuminants).
enum StandardIlluminant
{
    /// Incandescent / Tungsten
    A =   xyY(0.44757, 0.40745, 1.00000),
    /// [obsolete] Direct sunlight at noon
    B =   xyY(0.34842, 0.35161, 1.00000),
    /// [obsolete] Average / North sky Daylight
    C =   xyY(0.31006, 0.31616, 1.00000),
    /// Horizon Light, ICC profile PCS (Profile connection space)
    D50 = xyY(0.34567, 0.35850, 1.00000),
    /// Mid-morning / Mid-afternoon Daylight
    D55 = xyY(0.33242, 0.34743, 1.00000),
    /// ACES Cinema
    D60 = xyY(0.32168, 0.33767, 1.00000),
    /// Noon Daylight: Television, sRGB color space
    D65 = xyY(0.31271, 0.32902, 1.00000),
    /// North sky Daylight
    D75 = xyY(0.29902, 0.31485, 1.00000),
    /// Used by Japanese NTSC
    D93 = xyY(0.28486, 0.29322, 1.00000),
    /// DCI-P3 digital cinema projector
    DCI = xyY(0.31400, 0.35100, 1.00000),
    /// Equal energy
    E =   xyY(1.0/3.0, 1.0/3.0, 1.00000),
    /// Daylight Fluorescent
    F1 =  xyY(0.31310, 0.33727, 1.00000),
    /// Cool White Fluorescent
    F2 =  xyY(0.37208, 0.37529, 1.00000),
    /// White Fluorescent
    F3 =  xyY(0.40910, 0.39430, 1.00000),
    /// Warm White Fluorescent
    F4 =  xyY(0.44018, 0.40329, 1.00000),
    /// Daylight Fluorescent
    F5 =  xyY(0.31379, 0.34531, 1.00000),
    /// Lite White Fluorescent
    F6 =  xyY(0.37790, 0.38835, 1.00000),
    /// D65 simulator, Daylight simulator
    F7 =  xyY(0.31292, 0.32933, 1.00000),
    /// D50 simulator, Sylvania F40 Design 50
    F8 =  xyY(0.34588, 0.35875, 1.00000),
    /// Cool White Deluxe Fluorescent
    F9 =  xyY(0.37417, 0.37281, 1.00000),
    /// Philips TL85, Ultralume 50
    F10 = xyY(0.34609, 0.35986, 1.00000),
    /// Philips TL84, Ultralume 40
    F11 = xyY(0.38052, 0.37713, 1.00000),
    /// Philips TL83, Ultralume 30
    F12 = xyY(0.43695, 0.40441, 1.00000)
}

///
xyY getStandardIlluminant(const(char)[] name) @safe pure
{
    import std.exception : enforce;

    xyY r;
    enforce(getStandardIlluminant(name, r), "No standard illuminant: " ~ name);
    return r;
}

///
bool getStandardIlluminant(const(char)[] name, out xyY illuminant) @safe pure nothrow @nogc
{
    // TODO: binary search!
    foreach (i; 0 .. names.length)
    {
        if (name[] == names[i][])
        {
            illuminant = illuminants[i];
            return true;
        }
    }
    return false;
}

///
string standardIlluminantName(xyY illuminant) @safe pure nothrow @nogc
{
    foreach (i; 0 .. illuminants.length)
    {
        if (illuminant == illuminants[i]) // can we depend on precise float equality? compare with epsilon?
            return names[i];
    }
    return null;
}

private:

// TODO: oh noes! first phobos include!
import std.traits : EnumMembers;

__gshared immutable string[] names = [ __traits(allMembers, StandardIlluminant) ];
__gshared immutable xyY[] illuminants = [ EnumMembers!(StandardIlluminant) ];
