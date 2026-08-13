using AimPark.API.DTOs;
using AimPark.API.Enums;

namespace AimPark.API.Tests.Fixtures;

/// <summary>
/// A real ML Kit reading of an STI registration and assessment form.
/// </summary>
/// <remarks>
/// Box coordinates, confidence values, and OCR damage are reproduced exactly from a
/// probe run against a photographed form at 3200x4154. The rules key on geometry and
/// on the damage patterns, so this exercises them the way a real submission would.
///
/// The personal values are replaced with invented ones of the same shape — the
/// student number keeps its length and leading zero, the names keep their cell
/// structure. Nothing here identifies anyone, and the rules cannot tell the
/// difference because they never look at the values, only at where they sit.
///
/// Two deliberate traps are preserved because both nearly broke the extractor:
///   - "Student Information" sits above "Student No" and is close enough to be
///     mistaken for that label.
///   - "J4Y1" falls inside the vertical gap above "Middle Name" and would be
///     collected if column overlap were not checked.
/// </remarks>
public static class RafProbeFixture
{
    public static OcrPayloadDto Payload() => new()
    {
        DocumentType = DocumentType.Raf,
        ImageWidth = 3200,
        ImageHeight = 4154,
        Lines =
        [
            Line("STI", 78, 78, 327, 172, 0.66),
            Line("STI COLLEGE BALIUAG", 1160, 124, 812, 82, 0.81),
            Line("Registration and", 2600, 97, 325, 50, 0.91),
            Line("Assessment Form", 2565, 145, 361, 48, 0.82),

            // Header table. Labels below values on the left group, beside values on
            // the right group — one form, two layouts.
            Line("Student Information", 97, 372, 435, 64, 0.84),
            Line("02000199887", 278, 456, 264, 41, 0.91),
            Line("Student No", 308, 525, 216, 41, 0.83),

            Line("SY & Tem:", 707, 386, 218, 53, 0.76),
            Line("2627/1T", 1081, 391, 162, 55, 0.75),

            Line("SANTOS", 986, 467, 140, 37, 0.85),
            Line("Last Name", 971, 534, 199, 39, 0.82),

            Line("Program:", 1424, 399, 176, 50, 0.75),
            Line("BSIT", 1827, 387, 96, 49, 0.66),
            Line("MARIA ELENA", 1695, 455, 225, 38, 0.76),
            Line("First Name", 1717, 522, 194, 35, 0.82),

            Line("Year Level:", 2215, 372, 204, 41, 0.78),
            Line("J4Y1", 2599, 359, 72, 50, 0.60),
            Line("CRUZ", 2454, 427, 246, 46, 0.81),
            Line("Middle Name", 2457, 490, 242, 42, 0.81),

            // Subject table. The section repeats once per subject, and OCR damages
            // some copies — "BSIT-48" for "BSIT-4B", units run together with the
            // class number.
            Line("Course Description", 130, 661, 382, 49, 0.85),
            Line("Units", 969, 667, 91, 36, 0.78),
            Line("Class No/Sec.", 1196, 649, 289, 43, 0.78),
            Line("3.00 14381 /BSIT-48", 977, 705, 437, 64, 0.77),
            Line("3,0014385 / BSIT-4B", 977, 802, 449, 65, 0.78),
            Line("14387 / BSIT-4B", 1117, 955, 301, 46, 0.81),
            Line("14386/ BSIT-4B", 1124, 1052, 305, 50, 0.81),
            Line("1.0014378 / BSIT 4B", 989, 1151, 434, 58, 0.82),
            Line("14384 / BSIT-4B", 1125, 1216, 295, 48, 0.80),
            Line("14382/ BSIT-4B", 1126, 1311, 296, 50, 0.76),
            Line("Total Units: 19.00", 724, 1389, 352, 46, 0.80),

            // The readable term, printed in the financial section. OCR splits the
            // ordinal into "1 st".
            Line("CHARGES for 2026-2027/1 st Term", 262, 1653, 666, 55, 0.86),
            Line("REGISTRATION FEE", 260, 1777, 404, 47, 0.80),
            Line("TUITION FEES", 259, 1843, 286, 43, 0.76),

            Line("Date Printed: 7/17/2026 2:29:52 PM", 2326, 3904, 660, 48, 0.86),
            Line("Page: 1 of 1", 2756, 3953, 218, 51, 0.86),
        ]
    };

    private static OcrLineDto Line(string text, int x, int y, int w, int h, double confidence)
        => new() { Text = text, X = x, Y = y, W = w, H = h, Confidence = confidence };
}
