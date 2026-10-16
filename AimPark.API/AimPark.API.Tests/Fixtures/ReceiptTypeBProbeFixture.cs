using AimPark.API.DTOs;
using AimPark.API.Enums;

namespace AimPark.API.Tests.Fixtures;

/// <summary>
/// A real ML Kit reading of the older LTO Official Receipt layout, photographed with
/// the OCR debug app.
/// </summary>
/// <remarks>
/// Box coordinates, confidence values and OCR damage are reproduced exactly. The
/// owner, address, plate, file, transaction and receipt numbers and the officers'
/// names are replaced with invented values of the same shape.
///
/// This layout differs from <see cref="ReceiptProbeFixture"/> in the ways that
/// matter to the rules:
///   - There is no "Vehicle Type:" or "Color:" label. The vehicle is described by
///     two unlabelled lines, "PRIVATE Nolbrcyce whout Sid" and "e CarMCGASRed",
///     where OCR has dropped the slashes of "Car/MC/GAS/Red". The "Car" there is
///     not the vehicle type.
///   - There is no "valid until" sentence. The registration runs to the end of the
///     window on "HEXT REG RENEWAL JAN 12026 to MAR 31 2026", whose first date OCR
///     damaged.
///   - "DATE" came back as "CATE" and its value lost a slash.
///   - Most lines read between 0.4 and 0.7, against 0.75 to 0.9 on the newer layout.
/// </remarks>
public static class ReceiptTypeBProbeFixture
{
    public const string Plate = "48210K";
    public const string Colour = "Red";
    public static readonly DateTime Expiry = new(2026, 3, 31, 0, 0, 0, DateTimeKind.Utc);

    public const string ExpiryLine = "HEXT REG RENEWAL JAN 12026 to MAR 31 2026";
    public const string VehicleLine = "e CarMCGASRed";

    public static OcrPayloadDto Payload() => new()
    {
        DocumentType = DocumentType.OfficialReceipt,
        ImageWidth = 2448,
        ImageHeight = 3264,
        Lines =
        [
            Line("Fied Olce San Rafacl DO", 338, 608, 444, 44, 0.60),
            Line("OFFICIAL'RECEIPT", 416, 680, 441, 54, 0.65),
            Line("SANTOS, ALBERTOR", 364, 817, 496, 62, 0.62),
            Line("RECEVED FROM Las Nare FisNane, Mi)", 369, 760, 708, 55, 0.48),
            Line("ADDRESS (No. Street. Cty. Munopality Provnce, Zp Code)", 375, 875, 892, 71, 0.61),
            Line("Transacton", 409, 1117, 183, 48, 0.67),
            Line("BARANGAY UNO SAMPLE TOWN BULACAN O", 420, 931, 611, 59, 0.72),
            Line("VRENO1", 679, 1130, 128, 41, 0.70),
            Line("Posled AD 30 2025", 421, 1231, 282, 48, 0.69),
            Line("CEPARTNENT OF TRANSPORTATICN", 903, 324, 707, 93, 0.72),
            Line("LAND TRANSPORTATION OFFICE", 873, 402, 776, 99, 0.82),
            Line("SAN RAFAEL BULACAN", 1055, 498, 403, 62, 0.74),
            Line("PAYMENT DETAIL.S", 622, 1047, 395, 63, 0.66),
            Line("PRIVATE Nolbrcyce whout Sid", 425, 1286, 461, 61, 0.59),
            Line(VehicleLine, 430, 1343, 271, 46, 0.57),
            Line("003160511202500)7- 01", 684, 1181, 393, 64, 0.68),
            Line("Fle No 030102C00987600", 451, 1400, 382, 50, 0.56),
            Line("CASH", 440, 1947, 88, 31, 0.77),
            Line("AR: NIA", 435, 2335, 133, 34, 0.68),
            Line("Plate No.: 48210K", 440, 1443, 506, 75, 0.69),
            Line("Gross VWeght 115", 443, 1510, 251, 48, 0.61),
            Line("031625000009999", 954, 662, 503, 74, 0.85),
            Line(ExpiryLine, 435, 2389, 734, 53, 0.76),
            Line("THE TOTAL SUM OF (n pesos", 432, 2530, 463, 43, 0.73),
            Line("tiol valid d not accompaned by CR and CPCil for hire.", 434, 2445, 831, 62, 0.59),
            Line("S45.01", 1156, 1965, 88, 36, 0.41),
            Line("MODE OF PAYMENT: CASH", 440, 2655, 433, 52, 0.72),
            Line("Five Hundred Forty Five And 81/100 Pesos Only", 429, 2580, 863, 70, 0.80),
            Line("NOGarcia", 659, 2879, 208, 48, 0.46),
            Line("CHIEF OF OFFICE", 637, 2937, 258, 43, 0.62),
            Line("Legal Research Fu3", 1309, 1138, 346, 53, 0.78),
            Line("MVUC", 1309, 1202, 104, 43, 0.67),
            Line("Felo Otf co Coce", 1452, 581, 300, 52, 0.49),
            Line("CATE", 1640, 657, 105, 50, 0.75),
            Line("TIN", 1684, 746, 59, 43, 0.74),
            Line("BREAKDoWN OF PAYMENT", 1405, 1049, 676, 74, 0.77),
            Line("Penalty", 1310, 1262, 117, 46, 0.81),
            Line("Penalty-Sc Tax", 1312, 1320, 239, 45, 0.69),
            Line("Sc Tax", 1312, 1375, 110, 37, 0.71),
            Line("Comp Fee", 1311, 1428, 167, 49, 0.78),
            Line("\"Nothing Follows\"*", 1314, 1486, 298, 51, 0.68),
            Line("TOTALAMOUNT-AID:", 1351, 2556, 345, 73, 0.59),
            Line("Ths 1s a 5ystun generated Olioal Hecepl No sgnaturos needed", 545, 2767, 1002, 96, 0.48),
            Line("MSE Npir0", 1266, 2902, 161, 59, 0.31),
            Line("CASHIE R", 1278, 2961, 138, 43, 0.62),
            Line("0316", 1958, 604, 79, 42, 0.75),
            Line("04/3012025 05:04:37 PM", 1819, 662, 391, 72, 0.73),
            Line("10.00", 2103, 1160, 88, 38, 0.82),
            Line("240.00", 2078, 1218, 109, 43, 0.83),
            Line("120.00", 2077, 1282, 103, 37, 0.77),
            Line("2.25", 2104, 1341, 71, 35, 0.81),
            Line("4.50", 2099, 1398, 68, 36, 0.78),
            Line("169.06", 2060, 1457, 99, 34, 0.81),
            Line("negA5.84", 1942, 2576, 194, 60, 0.30),
        ]
    };

    /// <summary>A copy of the payload without the line carrying <paramref name="text"/>.</summary>
    public static OcrPayloadDto Without(string text)
    {
        var source = Payload();
        source.Lines = source.Lines.Where(l => l.Text != text).ToList();
        return source;
    }

    /// <summary>A copy of the payload with one more line.</summary>
    public static OcrPayloadDto With(OcrLineDto extra)
    {
        var source = Payload();
        source.Lines.Add(extra);
        return source;
    }

    public static OcrLineDto Line(string text, int x, int y, int w, int h, double confidence)
        => new() { Text = text, X = x, Y = y, W = w, H = h, Confidence = confidence };
}
