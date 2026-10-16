using AimPark.API.DTOs;
using AimPark.API.Enums;

namespace AimPark.API.Tests.Fixtures;

/// <summary>
/// Two real ML Kit readings of one Philippine driver's licence, photographed twice
/// with the OCR debug app.
/// </summary>
/// <remarks>
/// Box coordinates, confidence values and OCR damage are reproduced exactly. The
/// name, licence number, birth date and address are replaced with invented values of
/// the same shape. The rules never look at the values, only at where they sit.
///
/// Both readings defeated the old "next line in reading order" rule the same way:
/// "License No.", "Expiration Date" and "Agency Code" sit side by side, so the line
/// after each caption was the next caption. Each reading adds its own damage:
///   - <see cref="First"/> splits the expiry as "2028/0 3/15".
///   - <see cref="Second"/> misreads the "License No." caption as "LjcenseNd.".
/// In both, the licence number and the expiry come back as one OCR line.
/// </remarks>
public static class LicenceProbeFixture
{
    public const string Name = "GARCIA, PAOLO MIGUEL TORRES";
    public const string Number = "C6624004321";
    public static readonly DateTime Expiry = new(2028, 3, 15, 0, 0, 0, DateTimeKind.Utc);
    public static readonly DateTime BirthDate = new(2004, 3, 15, 0, 0, 0, DateTimeKind.Utc);
    public static readonly DateTime IssueDate = new(2024, 2, 2, 0, 0, 0, DateTimeKind.Utc);

    /// <summary>The merged number-and-expiry line in <see cref="Second"/>.</summary>
    public const string SecondValueLine = "C66-24-004321 2028/03/15";

    public static OcrPayloadDto First() => Payload(
    [
        Line("2024/02/02", 408, 1908, 218, 51, 0.69),
        Line("C66-24-pom4s kevGARC", 328, 1967, 303, 34, 0.30),
        Line("REPUBLIC OFTHE PHILIPPINES", 635, 1015, 1022, 61, 0.84),
        Line("Signáture of Licensee", 324, 2126, 393, 45, 0.64),
        Line("DEPARTMENT OF TRANSPORTATION", 776, 1072, 740, 45, 0.84),
        Line("LAND TRANSPORTATION OFFICE", 814, 1110, 663, 48, 0.82),
        Line("DRIVERS LICENSE", 828, 1177, 617, 60, 0.76),
        Line("Last Narne. First fName. Middie Name", 819, 1291, 675, 51, 0.70),
        Line(Name, 818, 1325, 1137, 87, 0.78),
        Line("Nationality Sèx", 821, 1436, 336, 45, 0.77),
        Line("PHL", 821, 1488, 101, 45, 0.81),
        Line("Address", 837, 1558, 127, 46, 0.79),
        Line("M", 1100, 1488, 47, 42, 0.82),
        Line("Blood Type", 825, 1869, 195, 42, 0.70),
        Line("O+", 889, 1914, 67, 41, 0.45),
        Line("Dale of Birth", 1250, 1427, 224, 46, 0.78),
        Line("2004/03115", 1245, 1474, 273, 58, 0.66),
        Line("-, SAN JOSE, CITY OF MALOLGS", 823, 1592, 1217, 73, 0.70),
        Line("(CAPITAL), BULACAN, 3000", 828, 1660, 780, 73, 0.73),
        Line("License No.", 824, 1751, 205, 39, 0.71),
        Line("Expiratidn Date", 1302, 1732, 275, 52, 0.71),
        Line("C66-24-004321 2028/0 3/15", 823, 1780, 755, 64, 0.87),
        Line("DŁ Codes", 827, 1992, 171, 34, 0.73),
        Line("A,B", 879, 2034, 88, 48, 0.63),
        Line("Eyes Oolor", 1165, 1863, 191, 46, 0.70),
        Line("BROWN", 1157, 1902, 208, 52, 0.83),
        Line("Weight (kg) Heigtit(m)", 1593, 1423, 437, 47, 0.71),
        Line("69", 1667, 1479, 55, 42, 0.85),
        Line("1.61", 1897, 1468, 99, 50, 0.64),
        Line("Conditians", 1170, 1984, 191, 36, 0.82),
        Line("NONE", 1189, 2030, 153, 42, 0.76),
        Line("Agency Code", 1696, 1729, 236, 48, 0.72),
        Line("C66", 1766, 1783, 98, 43, 0.70),
        Line("ATTYMGORE. MEND0ZA IE", 1474, 2054, 525, 54, 0.60),
        Line("Assistant Secretary", 1567, 2110, 364, 40, 0.77),
    ]);

    public static OcrPayloadDto Second() => Payload(
    [
        Line("REPUBLIC OF THE PHILIPPINES", 586, 672, 1260, 110, 0.84),
        Line("DEPARTMENT OF TRANSPORTATION", 766, 750, 908, 78, 0.85),
        Line("LAND TRANSPORTATION OFFICE", 813, 806, 812, 73, 0.83),
        Line("20240202", 338, 1733, 255, 54, 0.63),
        Line("66-24-oar21 GaRCIAPAOLO", 265, 1795, 336, 32, 0.38),
        Line("Signature of Licensee", 254, 1956, 448, 49, 0.61),
        Line("DRIVERS LICENSE", 828, 887, 739, 86, 0.79),
        Line("Lest Nane. First ftiame. Middie Name", 819, 1034, 805, 71, 0.67),
        Line(Name, 816, 1090, 1330, 107, 0.78),
        Line("Nationality Sex Date of Birth", 819, 1200, 772, 71, 0.74),
        Line("PHL", 819, 1263, 119, 52, 0.81),
        Line("M 2004/03I15", 1150, 1268, 487, 64, 0.68),
        Line("Address", 823, 1348, 176, 45, 0.75),
        Line("LjcenseNd.", 821, 1565, 238, 45, 0.61),
        Line("Expiration Date", 1365, 1565, 309, 51, 0.77),
        Line(SecondValueLine, 819, 1604, 850, 67, 0.85),
        Line("-, SAN JOSE, CITY OF MALOLGS", 820, 1408, 1378, 79, 0.70),
        Line("(CAPITAL), BULACAN, 3000", 818, 1478, 894, 73, 0.71),
        Line("Blood Type", 821, 1697, 221, 46, 0.64),
        Line("O+", 894, 1743, 79, 44, 0.42),
        Line("DL Codes", 841, 1822, 171, 46, 0.74),
        Line("A,B", 880, 1870, 99, 48, 0.69),
        Line("Eyes Oolor", 1207, 1702, 211, 41, 0.66),
        Line("BROWN", 1194, 1744, 229, 52, 0.85),
        Line("Weight (kg) Height(m)", 1721, 1227, 492, 57, 0.72),
        Line("1.61", 2059, 1292, 108, 50, 0.61),
        Line("Conditians", 1206, 1830, 211, 34, 0.79),
        Line("NONE", 1223, 1870, 168, 47, 0.71),
        Line("69", 1799, 1290, 65, 46, 0.82),
        Line("Agenty Code", 1804, 1574, 255, 49, 0.72),
        Line("C66", 1872, 1626, 105, 50, 0.79),
        Line("ATTYIGORE. MENDOZA IE", 1529, 1907, 555, 55, 0.60),
        Line("Assistant Secretary", 1625, 1962, 382, 45, 0.82),
    ]);

    /// <summary>A copy of <paramref name="payload"/> with one line's text replaced.</summary>
    public static OcrPayloadDto Replace(OcrPayloadDto payload, string text, string replacement)
    {
        var copy = Payload(payload.Lines.Select(Copy).ToList());
        copy.Lines.Single(l => l.Text == text).Text = replacement;
        return copy;
    }

    /// <summary>A copy of <paramref name="payload"/> without the line carrying <paramref name="text"/>.</summary>
    public static OcrPayloadDto Without(OcrPayloadDto payload, string text)
        => Payload(payload.Lines.Where(l => l.Text != text).Select(Copy).ToList());

    /// <summary>A copy of <paramref name="payload"/> with one more line.</summary>
    public static OcrPayloadDto With(OcrPayloadDto payload, OcrLineDto extra)
        => Payload([.. payload.Lines.Select(Copy), extra]);

    public static OcrLineDto Line(string text, int x, int y, int w, int h, double confidence)
        => new() { Text = text, X = x, Y = y, W = w, H = h, Confidence = confidence };

    private static OcrLineDto Copy(OcrLineDto l) => Line(l.Text, l.X, l.Y, l.W, l.H, l.Confidence);

    private static OcrPayloadDto Payload(List<OcrLineDto> lines) => new()
    {
        DocumentType = DocumentType.License,
        ImageWidth = 2448,
        ImageHeight = 3264,
        Lines = lines
    };
}
