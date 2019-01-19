module wg.color.rgb.chromatic_adaptation;

import wg.color.xyz;
import wg.util.math;

/**
 Chromatic adaptation method.
 */
enum ChromaticAdaptationMethod
{
    /** Direct method, no correction for cone response. */
    XYZ,
    /** Bradford method. Considered by most experts to be the best. */
    Bradford,
    /** Von Kries method. */
    VonKries
}

/**
 Generate a chromatic adaptation matrix from $(D_INLINECODE srcWhite) to $(D_INLINECODE destWhite).

 Chromatic adaptation is the process of transforming colors relative to a particular white point to some other white point.
 Information about chromatic adaptation can be found at $(LINK2 https://en.wikipedia.org/wiki/Chromatic_adaptation, wikipedia).
 */
float[3][3] chromaticAdaptationMatrix(ChromaticAdaptationMethod method = ChromaticAdaptationMethod.Bradford)(xyY srcWhite, xyY destWhite) @safe pure nothrow @nogc
{
    enum Ma = chromaticAdaptationMatrices[method];
    enum iMa = inverse(Ma);
    auto XYZs = convertColor!XYZ(srcWhite);
    auto XYZd = convertColor!XYZ(destWhite);
    float[3] Ws = [ XYZs.X, XYZs.Y, XYZs.Z ];
    float[3] Wd = [ XYZd.X, XYZd.Y, XYZd.Z ];
    auto s = multiply(Ma, Ws);
    auto d = multiply(Ma, Wd);
    float[3][3] t = [[d[0]/s[0], 0,         0        ],
                     [0,         d[1]/s[1], 0        ],
                     [0,         0 ,        d[2]/s[2]]];
    return multiply(multiply(iMa, t), Ma);
}


private:

__gshared immutable float[3][3][ChromaticAdaptationMethod.max + 1] chromaticAdaptationMatrices = [
    // XYZ (identity) matrix
    [[ 1, 0, 0 ],
     [ 0, 1, 0 ],
     [ 0, 0, 1 ]],
    // Bradford matrix
    [[  0.89510,  0.26640, -0.16140 ],
     [ -0.75020,  1.71350,  0.03670 ],
     [  0.03890, -0.06850,  1.02960 ]],
    // Von Kries matrix
    [[  0.40024,  0.70760, -0.08081 ],
     [ -0.22630,  1.16532,  0.04570 ],
     [  0.00000,  0.00000,  0.91822 ]]
];
