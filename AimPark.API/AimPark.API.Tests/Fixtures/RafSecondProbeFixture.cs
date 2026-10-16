using AimPark.API.DTOs;
using AimPark.API.Enums;

namespace AimPark.API.Tests.Fixtures;

/// <summary>
/// A second real ML Kit reading of an STI registration and assessment form, taken
/// with the OCR debug app on a different form and phone from
/// <see cref="RafProbeFixture"/>.
/// </summary>
/// <remarks>
/// Box coordinates, confidence values and OCR damage are reproduced exactly. The
/// student's name, number and email, and the instructors' names, are replaced with
/// invented values of the same shape.
///
/// Kept as a regression guard: the position-based licence and receipt changes reuse
/// the same layout helpers the RAF depends on, and this form must still read all
/// four fields.
/// </remarks>
public static class RafSecondProbeFixture
{
    public const string StudentNumber = "02000111222";
    public const string StudentName = "GARCIA, PAOLO MIGUEL TORRES";
    public const string Section = "BSIT-4B";
    public const string Semester = "2026-2027/1st Term";

    public static OcrPayloadDto Payload() => new()
    {
        DocumentType = DocumentType.Raf,
        ImageWidth = 2448,
        ImageHeight = 3264,
        Lines =
        [
            Line("STI", 36, 259, 199, 126, 0.64),
            Line("Student Information", 9, 472, 316, 41, 0.86),
            Line("02000111222", 138, 525, 197, 36, 0.91),
            Line("Student No", 159, 579, 161, 31, 0.84),
            Line("Course Description", 33, 681, 275, 38, 0.87),
            Line("Information Assurance and Security", 24, 723, 527, 45, 0.85),
            Line("(Data Privacy)", 40, 764, 191, 46, 0.83),
            Line("Network Technology 2", 30, 802, 328, 48, 0.85),
            Line("Computer Graphics Programming", 50, 924, 482, 44, 0.87),
            Line("IT Service Management", 50, 1013, 347, 35, 0.78),
            Line("Euthenics 2", 52, 1090, 174, 37, 0.78),
            Line("SY & Term:", 460, 460, 173, 39, 0.72),
            Line("Game Development", 65, 1145, 286, 32, 0.87),
            Line("IECapstone Projeot 2", 78, 1217, 306, 43, 0.57),
            Line("REGISTRATION FEE", 152, 1561, 308, 31, 0.81),
            Line("TUITION FEES", 156, 1607, 217, 34, 0.78),
            Line("CHARGES for 2026-2027/1st Term", 144, 1468, 521, 35, 0.86),
            Line("OTHER SCHOOL FEES", 164, 1654, 343, 35, 0.78),
            Line("MISCELLANEOUS FEES", 169, 1696, 357, 38, 0.78),
            Line("2627/1T", 748, 443, 134, 46, 0.80),
            Line("GARCIA", 679, 506, 111, 34, 0.85),
            Line("Last Name", 667, 560, 157, 36, 0.88),
            Line("Units", 668, 672, 72, 28, 0.73),
            Line("ADDITIONAL CHARGES", 163, 1946, 369, 44, 0.85),
            Line("3,00", 675, 722, 60, 28, 0.80),
            Line("CREDIT ADJUSTMENT", 163, 1993, 351, 48, 0.82),
            Line("3,00", 679, 805, 61, 28, 0.77),
            Line("3.00", 684, 926, 61, 27, 0.76),
            Line("3.00", 703, 1217, 62, 28, 0.85),
            Line("Total Units: 19.00", 507, 1258, 276, 36, 0.77),
            Line("1.00", 697, 1089, 60, 26, 0.88),
            Line("3.00", 698, 1140, 62, 25, 0.84),
            Line("2/F A&C Bldg., Gil Caros s Poblacion, Baliuag, Bulacan", 766, 287, 744, 62, 0.76),
            Line("Tel. No. 044 7666722", 1011, 336, 266, 42, 0.79),
            Line("STI COLLEGE BALIUAG", 826, 221, 643, 88, 0.78),
            Line("OTHER CHARGES AND ADJUSTMENTS", 170, 1842, 610, 57, 0.83),
            Line("SCHOLARSHIP/DISCOUNT", 168, 1893, 430, 48, 0.78),
            Line("Class No / Sec.", 850, 665, 224, 36, 0.81),
            Line("14381 /BSIT-48", 792, 718, 234, 33, 0.73),
            Line("3.00 14386 / BSIT-4B", 689, 1001, 351, 38, 0.78),
            Line("14385 / BSIT-4B", 787, 801, 241, 32, 0.77),
            Line("Program:", 1028, 451, 141, 43, 0.77),
            Line("14387 / BSIT-4B", 794, 918, 242, 38, 0.72),
            Line("Student Group: STI SHS Alumni Scholarship 50%", 325, 1355, 756, 50, 0.85),
            Line("Student Group: Tertiary - Cash", 328, 1410, 474, 46, 0.87),
            Line("ACADEMIC", 1021, 607, 231, 43, 0.75),
            Line("14378 / BSIT-4B", 804, 1082, 236, 32, 0.77),
            Line("14384 / BSIT-4B", 808, 1135, 236, 29, 0.78),
            Line("Total Assessnent", 625, 1778, 265, 35, 0.81),
            Line("14382 / BSIT-4B", 810, 1207, 235, 37, 0.82),
            Line("Net Assessment", 636, 2028, 233, 41, 0.85),
            Line("682.00", 1036, 1540, 90, 26, 0.84),
            Line("20,590.00", 994, 1583, 135, 36, 0.84),
            Line("e.g. for December 31, 2018, YYYYMMDD is 20181231", 81, 2422, 819, 90, 0.83),
            Line("5.626.00", 1013, 1632, 116, 30, 0.78),
            Line("4,400.00", 1014, 1677, 118, 28, 0.78),
            Line("31,298.00", 1000, 1763, 134, 37, 0.84),
            Line("(10,295.00)", 984, 1866, 153, 39, 0.84),
            Line("Email account/username: garcia.111222@baliuag.sti.edu.ph", 97, 2323, 919, 94, 0.72),
            Line("21.003.00", 1009, 2010, 133, 36, 0.90),
            Line("BSIT", 1352, 435, 76, 43, 0.75),
            Line("PAOLO MIGUEL", 1242, 494, 193, 38, 0.79),
            Line("Days", 1196, 667, 72, 34, 0.89),
            Line("M", 1217, 757, 29, 30, 0.73),
            Line("FINANCIAL", 1043, 1307, 226, 29, 0.71),
            Line("M", 1217, 800, 30, 25, 0.56),
            Line("W", 1220, 841, 29, 22, 0.69),
            Line("T", 1227, 921, 17, 27, 0.47),
            Line("Your password is GarciaYYYYMMDD where YYYYMMDD is your birthdate", 82, 2362, 1100, 105, 0.85),
            Line("T", 1225, 960, 21, 26, 0.41),
            Line("T", 1228, 1002, 16, 27, 0.41),
            Line("W", 1227, 1080, 24, 26, 0.42),
            Line("1 ta the APkon your phone.", 1391, -3, 336, 56, 0.48),
            Line("First Name", 1260, 551, 160, 35, 0.85),
            Line("R tedoe ye ARcence or R", 1428, 62, 448, 72, 0.40),
            Line("SPONSORSHIP", 1178, 1397, 224, 26, 0.83),
            Line("PAYMENT", 1178, 1442, 145, 28, 0.85),
            Line("REFUND", 1177, 1491, 123, 28, 0.80),
            Line("Time", 1452, 657, 73, 29, 0.82),
            Line("9:30AM-11:30AM", 1323, 700, 279, 44, 0.81),
            Line("|12:30PM - 3:30PM", 1326, 741, 275, 41, 0.82),
            Line("3:30PM -5:30PM", 1324, 787, 258, 40, 0.82),
            Line("11:00AM-2:00PM", 1327, 827, 273, 37, 0.83),
            Line("1:00PM-3:00PM", 1328, 865, 251, 37, 0.84),
            Line("8:00AM - 10:00AM", 1325, 906, 275, 39, 0.82),
            Line("1:00PM - 4:00PM", 1328, 947, 252, 36, 0.83),
            Line("10:30AM -12:00PM", 1336, 985, 284, 45, 0.83),
            Line("9:30AM -11:00AM", 1321, 1024, 276, 40, 0.85),
            Line("3:00PM - 4:00PM", 1327, 1071, 251, 36, 0.81),
            Line("7:30AM-9:30AM", 1321, 1121, 256, 36, 0.82),
            Line("9:30AM - 12:30PM", 1328, 1158, 268, 39, 0.81),
            Line("1:00PM - 4:00PM", 1329, 1197, 249, 36, 0.80),
            Line("PAYMENTS AND OTHER ADJUSTMENTS", 1177, 1345, 619, 37, 0.84),
            Line("PAYMENT SCHEDULE", 1184, 1686, 318, 36, 0.81),
            Line("You may access your student ernail account after three (3) working days. Your email credentials are:", 86, 2246, 1460, 126, 0.87),
            Line("Year Level:", 1664, 413, 185, 45, 0.80),
            Line("Room", 1718, 645, 89, 29, 0.84),
            Line("4Y1", 2000, 403, 68, 43, 0.66),
            Line("TORRES", 1878, 462, 210, 40, 0.84),
            Line("Middle Name", 1878, 519, 206, 37, 0.83),
            Line("Registration and", 2006, 146, 307, 66, 0.90),
            Line("Assessment Fom", 1976, 196, 335, 64, 0.84),
            Line("DELOSANT0,ANNA", 1865, 674, 339, 46, 0.76),
            Line("LIMA", 1863, 719, 168, 40, 0.82),
            Line("VILLANUEVA,MARCO", 1863, 756, 360, 52, 0.84),
            Line("Instructor", 2011, 626, 148, 35, 0.88),
            Line("ANTONIO", 1868, 809, 184, 34, 0.79),
            Line("VILLANUEVA,MARCO AN", 1867, 839, 415, 46, 0.83),
            Line("VILLANUEVA,MARCO", 1866, 885, 350, 44, 0.84),
            Line("|ANTONIO", 1865, 931, 179, 34, 0.76),
            Line("Net Balance", 1700, 1531, 181, 24, 0.90),
            Line("Total Current Balance", 1553, 1627, 319, 33, 0.85),
            Line("RAMOS,LIZA MAE", 1864, 971, 325, 40, 0.80),
            Line("|RAMOS,LIZA MAE", 1856, 1005, 338, 46, 0.78),
            Line("NAVARRO,MA.TERESA", 1862, 1053, 346, 41, 0.78),
            Line("BAUTISTA.JOHN PAUL", 1860, 1103, 304, 38, 0.78),
            Line("REYNA", 1858, 1145, 138, 37, 0.75),
            Line("MENDEZ, KARL-O", 1856, 1186, 277, 38, 0.80),
            Line("Total Outstanding Balance", 1509, 1755, 379, 46, 0.86),
            Line("THIS 1S A SYSTEM GENERATED ASSESSMENT. ANY ALTERATION BY THE SCHOOL OR ANY OTHER PARTY IS NOT AUTHORIZED AND MAY RENDER YoUR", 96, 2080, 1963, 142, 0.79),
            Line("ENROLLMENT AND PAYMENT INVALID. PLEASE REPORT ANY VIOLATION TO REPORT @STI.EDU.", 94, 2155, 1281, 108, 0.78),
            Line("(21,003.00)", 2044, 1416, 167, 41, 0.86),
            Line("0.00", 2136, 1518, 61, 23, 0.70),
            Line("0.00", 2115, 1609, 63, 26, 0.70),
            Line("Amout Due", 1956, 1704, 167, 34, 0.84),
            Line("0.00", 2118, 1743, 52, 26, 0.76),
            Line("717/2026 2:29:52 PM", 2009, 3193, 297, 73, 0.78),
        ]
    };

    private static OcrLineDto Line(string text, int x, int y, int w, int h, double confidence)
        => new() { Text = text, X = x, Y = y, W = w, H = h, Confidence = confidence };
}
