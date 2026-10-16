using AimPark.API.DTOs;
using AimPark.API.Enums;

namespace AimPark.API.Tests.Fixtures;

/// <summary>
/// Two real ML Kit readings of one LTO Official Receipt, photographed twice with the
/// OCR debug app.
/// </summary>
/// <remarks>
/// Box coordinates, confidence values and OCR damage are reproduced exactly. The
/// owner, address, plate, file, receipt and client numbers, TIN and cashier are
/// replaced with invented values of the same shape.
///
/// The two photos split the vehicle rows in opposite ways, which is the point of
/// keeping both:
///   - <see cref="First"/> returns "Color:" apart from "MATTE ORANGE/BLACK", but
///     "Vehicle Type: MC Without Sidecar" as one line.
///   - <see cref="Second"/> returns "Color: MATTE ORANGE/BLACK" as one line, but
///     "Vehicle Type:" apart from "MC Without Sidecar".
/// </remarks>
public static class ReceiptProbeFixture
{
    public const string Plate = "482KLM";
    public const string Color = "MATTE ORANGE/BLACK";
    public static readonly DateTime Expiry = new(2027, 5, 31, 0, 0, 0, DateTimeKind.Utc);

    public static OcrPayloadDto First() => Payload(
    [
        Line("of Tra", 524, 364, 116, 41, 0.46),
        Line("899", 549, 608, 37, 19, 0.64),
        Line("Field Office:", 393, 708, 185, 36, 0.78),
        Line("Ofice Code:", 398, 770, 184, 37, 0.76),
        Line("OFFICIAL RECEIPT", 480, 888, 415, 54, 0.76),
        Line("DEPARTMENT OF TRANSPORTATION", 852, 446, 735, 55, 0.80),
        Line("LAND TRANSPORTATION OFFICE", 819, 514, 797, 67, 0.78),
        Line("SAN RAFAEL DISTRICT OFFICE (BALIUAG)", 671, 711, 744, 65, 0.82),
        Line("0316", 1004, 795, 76, 30, 0.85),
        Line("RECEIVED FROM (Last Name, First Name Middle Name)", 462, 960, 890, 72, 0.84),
        Line("GARCIA, LUZ TORRESIMMC", 462, 1017, 697, 64, 0.79),
        Line("TIN (Tax ldentification Number)", 458, 1226, 486, 55, 0.83),
        Line("ADDRESS (No. Street, Barangay, Municjpality, Zip Code, Province)", 461, 1093, 1034, 79, 0.82),
        Line("123 Sample St, Poblacion, San Rafael, 3008, Bulacan", 461, 1152, 874, 71, 0.88),
        Line("Color:", 607, 1841, 84, 25, 0.90),
        Line("Year Model:", 505, 1891, 184, 28, 0.87),
        Line("CASHIER:", 372, 2478, 150, 31, 0.76),
        Line("DRT HI-WAY ULINGAO, SẬN RAFAEL, BULACAN", 850, 587, 735, 55, 0.78),
        Line("Republic of the Philippines", 1029, 402, 383, 44, 0.87),
        Line("PAYMENT DETAILS", 653, 1384, 353, 40, 0.79),
        Line("POS MACHINE:", 366, 2537, 238, 43, 0.75),
        Line("Transaction No: TX-MVIRS-20260807-", 478, 1447, 596, 49, 0.81),
        Line("389001", 772, 1493, 98, 30, 0.91),
        Line("Plate No: 482KLM", 479, 1521, 472, 60, 0.81),
        Line("M", 934, 1542, 19, 35, 0.59),
        Line("File No: 130300000123456", 605, 1576, 434, 49, 0.82),
        Line("Classification: Private - (PVT)", 503, 1623, 464, 49, 0.84),
        Line("Vehicle Type: MC Without Sidecar", 502, 1675, 538, 49, 0.86),
        Line("Fuel Type:", 545, 1729, 159, 42, 0.84),
        Line("Gas", 747, 1742, 58, 24, 0.82),
        Line("Aircon Type:NJA", 524, 1782, 278, 37, 0.80),
        Line("TOTAL AMOUNT PAID:", 394, 2164, 441, 38, 0.84),
        Line("AMOUNT IN WORDS:", 388, 2232, 406, 40, 0.84),
        Line("0316-000000123456", 1025, 910, 430, 52, 0.88),
        Line("MODE OF PAYMENT: Cash", 384, 2350, 446, 38, 0.84),
        Line("LOCATION:", 378, 2415, 173, 31, 0.80),
        Line(Color, 736, 1840, 357, 37, 0.80),
        Line("2019", 734, 1899, 76, 25, 0.88),
        Line("This payment is valid until", 727, 1948, 406, 41, 0.81),
        Line("05/2027 and due for", 726, 1983, 319, 38, 0.87),
        Line("renewal on 05/22/2027-", 722, 2023, 374, 37, 0.79),
        Line("05/31/2027.", 721, 2060, 186, 33, 0.82),
        Line("LTO Client |D/ LTO BUSINESS ID", 1030, 1248, 515, 54, 0.74),
        Line("23-200101-1234567", 1019, 1301, 335, 52, 0.90),
        Line("Juan Dela Cruz", 744, 2490, 312, 41, 0.88),
        Line("Delinguent Registration", 1238, 1472, 297, 48, 0.84),
        Line("SAN RAFAEL DO - CASHIER", 740, 2549, 436, 46, 0.80),
        Line("MVUC", 1225, 1545, 85, 29, 0.64),
        Line("Science Tax", 1221, 1602, 157, 32, 0.84),
        Line("San Rafael District Office (Baliuag)", 754, 2423, 497, 50, 0.87),
        Line("Science Tax Late", 1235, 1651, 213, 39, 0.77),
        Line("Registration", 1219, 1689, 157, 34, 0.90),
        Line("Legal Research Fee", 1218, 1723, 267, 37, 0.88),
        Line("TIN:", 1560, 742, 53, 38, 0.73),
        Line("Date:", 1541, 812, 81, 29, 0.84),
        Line("BREAKDOWN OF PAYMENT", 1298, 1404, 514, 61, 0.83),
        Line("PHP", 1617, 1498, 60, 23, 0.85),
        Line("PHP", 1612, 1568, 60, 20, 0.84),
        Line("PHP", 1607, 1620, 57, 22, 0.85),
        Line("PHP", 1604, 1672, 59, 23, 0.86),
        Line("PHP", 1530, 2182, 77, 33, 0.88),
        Line("PHP", 1606, 1739, 58, 23, 0.77),
        Line("ND", 1783, 436, 43, 43, 0.41),
        Line("TRANSPORTAY", 1797, 361, 183, 102, 0.62),
        Line("This is a system generated Officia Receipt. No Signatures needed.", 655, 2643, 987, 61, 0.82),
        Line("LTO", 1866, 514, 96, 34, 0.73),
        Line("000123456000", 1736, 750, 243, 37, 0.93),
        Line("Iment of Transp", 1802, 594, 193, 116, 0.64),
        Line("08/07/2026 4:17 PM", 1688, 812, 324, 40, 0.84),
        Line("120.00", 1807, 1507, 91, 25, 0.90),
        Line("360.00", 1796, 1576, 93, 24, 0.84),
        Line("6.00", 1825, 1631, 57, 21, 0.86),
        Line("3.00", 1818, 1676, 59, 27, 0.88),
        Line("FOUR HUNDRED NINETY-NINE PESOS", 1171, 2240, 747, 59, 0.83),
        Line("10.00", 1810, 1742, 71, 32, 0.86),
        Line("10,", 1974, 406, 39, 36, 0.35),
        Line("499.00", 1801, 2192, 118, 35, 0.87),
    ]);

    public static OcrPayloadDto Second() => Payload(
    [
        Line("7899", 459, 496, 74, 25, 0.63),
        Line("Field Office:", 308, 610, 208, 37, 0.77),
        Line("Office Code:", 309, 678, 214, 36, 0.77),
        Line("OFFICIAL RECEIPT", 395, 809, 485, 44, 0.75),
        Line("SAN RAFAEL DISTRICT OFFICE (BALIUAG)", 619, 603, 839, 63, 0.80),
        Line("0316", 996, 688, 88, 32, 0.87),
        Line("RECEIVED FROM (Last Name, First Name Middle Name)", 370, 887, 1024, 57, 0.85),
        Line("GARCIA, LUZ TORRESIMMC", 369, 952, 809, 52, 0.78),
        Line("ADDRESS (No. Street, Barangay, Municipality, Zip Code, Province)", 363, 1039, 1199, 66, 0.86),
        Line("123 Sample St, Poblacion, San Rafael, 3008, Bulacan", 363, 1101, 1018, 70, 0.89),
        Line("TIN (Tax ldentification Number)", 363, 1193, 566, 51, 0.85),
        Line("Transaction No:", 377, 1448, 281, 34, 0.89),
        Line("Republic of the Philippines", 1027, 282, 419, 37, 0.78),
        Line("DEPARTMENT OF TRANSPORTATION", 848, 322, 790, 50, 0.82),
        Line("LAND TRANSPORTATION OFFICE", 792, 390, 881, 61, 0.79),
        Line("DRT HI-WAY ULINGAO, SAN RAFAEL, BULACAN", 823, 467, 820, 54, 0.76),
        Line("PAYMENT DETAILS", 588, 1371, 413, 42, 0.78),
        Line("Plate No: 482KLM", 377, 1530, 561, 65, 0.85),
        Line("File No:", 516, 1599, 137, 38, 0.82),
        Line("Classification:", 402, 1659, 248, 35, 0.88),
        Line("Vehicle Type:", 399, 1715, 244, 48, 0.87),
        Line("Fuel Type:", 451, 1782, 185, 43, 0.88),
        Line("Aircon Type: N/A", 401, 1842, 343, 45, 0.80),
        Line("Year Model:", 404, 1973, 218, 37, 0.88),
        Line("LOCATION:", 290, 2589, 199, 33, 0.78),
        Line("CASHIER:", 310, 2653, 154, 43, 0.79),
        Line("389001", 708, 1495, 130, 35, 0.89),
        Line("MODE OF PAYMENT:", 290, 2518, 374, 38, 0.81),
        Line("POS MACHINE:", 294, 2724, 260, 43, 0.77),
        Line("TX-MVIRS-20260807-", 719, 1452, 370, 44, 0.79),
        Line("0316-000000123456", 1020, 812, 490, 57, 0.89),
        Line("Color: MATTE ORANGE/BLACK", 522, 1908, 590, 42, 0.78),
        Line("130300000123456", 706, 1603, 334, 42, 0.86),
        Line("Private (PVT)", 699, 1662, 254, 43, 0.71),
        Line("2019", 675, 1978, 86, 35, 0.83),
        Line("TOTAL AMOUNT PAID:", 287, 2302, 517, 46, 0.82),
        Line("AMOUNT IN WORDS:", 287, 2383, 472, 46, 0.81),
        Line(SecondVehicleTypeValue, 697, 1726, 352, 37, 0.88),
        Line("Gas", 692, 1790, 68, 31, 0.82),
        Line("LTO Client ID-/ LTO BUSINESS ID", 1018, 1205, 611, 46, 0.77),
        Line("23-200101-1234567", 1017, 1270, 392, 45, 0.92),
        Line("This payment is valid until", 669, 2043, 492, 44, 0.85),
        Line("05/2027 and due for", 686, 2086, 367, 43, 0.83),
        Line("renewal on 05/22/2027-", 665, 2133, 454, 44, 0.89),
        Line("05/31/2027.", 664, 2177, 222, 39, 0.84),
        Line("Cash", 729, 2532, 83, 32, 0.89),
        Line("Juan Dela Cruz", 720, 2676, 362, 45, 0.86),
        Line("SAN RAFAEL D0- CASHIER", 721, 2740, 506, 49, 0.78),
        Line("MVUC", 1261, 1553, 100, 30, 0.67),
        Line("TIN:", 1605, 629, 69, 33, 0.71),
        Line("Delinquent Registration", 1261, 1465, 369, 45, 0.85),
        Line("Science Tax", 1258, 1618, 195, 35, 0.75),
        Line("San Rafael District Office (Baliuag)", 728, 2599, 584, 61, 0.86),
        Line("Date:", 1604, 699, 89, 34, 0.85),
        Line("Science Tax Late", 1258, 1682, 277, 37, 0.78),
        Line("Registration", 1259, 1723, 187, 38, 0.89),
        Line("Legal Research Fee", 1259, 1761, 320, 43, 0.86),
        Line("BREAKDOWN OF PAYMENT", 1346, 1383, 608, 47, 0.81),
        Line("PHP", 1727, 1479, 71, 26, 0.90),
        Line("PHP", 1723, 1564, 69, 26, 0.89),
        Line("08/07/2026 4:17 PM", 1768, 699, 364, 38, 0.87),
        Line("PHP", 1718, 1631, 71, 26, 0.86),
        Line("PHP", 1712, 1691, 74, 30, 0.83),
        Line("PHP", 1719, 1773, 72, 31, 0.79),
        Line("PHP", 1641, 2323, 93, 39, 0.91),
        Line("tmoit", 1893, 495, 72, 55, 0.32),
        Line("000123456000", 1817, 630, 268, 37, 0.90),
        Line("This is a system generated Official Receipt. No Signatures needed.", 631, 2835, 1124, 61, 0.85),
        Line("120.00", 1952, 1480, 106, 31, 0.89),
        Line("360.00", 1945, 1567, 110, 28, 0.85),
        Line("6.00", 1982, 1637, 69, 26, 0.89),
        Line("3.00", 1979, 1701, 67, 26, 0.91),
        Line("FOUR HUNDRED NINETY-NINE PESOS", 1214, 2396, 889, 60, 0.82),
        Line("10.00", 1968, 1782, 85, 28, 0.83),
        Line("499.00", 1964, 2327, 141, 41, 0.92),
    ]);

    /// <summary>The value printed apart from its "Vehicle Type:" label in <see cref="Second"/>.</summary>
    public const string SecondVehicleTypeValue = "MC Without Sidecar";

    /// <summary>A copy of <paramref name="payload"/> without the line carrying <paramref name="text"/>.</summary>
    public static OcrPayloadDto Without(OcrPayloadDto payload, string text)
        => Payload(payload.Lines
            .Where(l => l.Text != text)
            .Select(l => Line(l.Text, l.X, l.Y, l.W, l.H, l.Confidence))
            .ToList());

    private static OcrLineDto Line(string text, int x, int y, int w, int h, double confidence)
        => new() { Text = text, X = x, Y = y, W = w, H = h, Confidence = confidence };

    private static OcrPayloadDto Payload(List<OcrLineDto> lines) => new()
    {
        DocumentType = DocumentType.OfficialReceipt,
        ImageWidth = 2448,
        ImageHeight = 3264,
        Lines = lines
    };
}
