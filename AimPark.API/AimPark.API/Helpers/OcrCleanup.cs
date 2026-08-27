using AimPark.API.DTOs;
using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Shared preparation applied to every OCR payload before any field rule runs.
    /// </summary>
    public static class OcrCleanup
    {
        // Below this, "we found some text" is not a claim worth making.
        private const int MinimumUsableLines = 5;

        // A page whose lines average worse than this was legible to the camera but
        // not to the reader. 0.90 was a clean line in testing, 0.31 was junk.
        private const double BlurryConfidenceThreshold = 0.55;

        // Past this share of rotated lines the page itself is sideways, rather than
        // carrying a rotated section.
        private const double SidewaysLineShare = 0.5;

        /// <summary>
        /// Drops rotated lines and returns the rest in reading order.
        /// </summary>
        public static List<OcrLineDto> Prepare(IEnumerable<OcrLineDto> lines)
            => SortReadingOrder(lines.Where(l => !IsRotated(l)));

        /// <summary>
        /// True when a line's box is taller than it is wide.
        /// </summary>
        /// <remarks>
        /// In the Philippines the OR and CR are printed on one sheet with the CR at
        /// 90°. Text recognition returns axis-aligned boxes, so rotated text comes
        /// back tall and narrow (17x246) while upright text is wide and short
        /// (153x19). This removed all CR noise in testing.
        ///
        /// Preferred over splitting the image left/right, which breaks the moment
        /// the sheet is photographed the other way round. Ambiguous only for one or
        /// two character fragments, which are noise either way.
        /// </remarks>
        public static bool IsRotated(OcrLineDto line) => line.H > line.W;

        /// <summary>
        /// Sorts top-to-bottom, then left-to-right within a row band.
        /// </summary>
        /// <remarks>
        /// Text recognition returns blocks in arbitrary order — in testing, block 0
        /// sat at y=104, block 1 at y=224, and block 2 at y=169. The concatenated
        /// "full text" it offers is therefore scrambled and must never be parsed.
        ///
        /// The band tolerance keeps a label and its value on one visual row from
        /// being separated by a few pixels of vertical drift.
        /// </remarks>
        public static List<OcrLineDto> SortReadingOrder(IEnumerable<OcrLineDto> lines)
        {
            var ordered = lines.ToList();
            if (ordered.Count == 0)
                return ordered;

            // Half a typical line height: tall enough to group one printed row,
            // short enough not to merge two.
            var band = Math.Max(1, (int)(ordered.Average(l => l.H) / 2));

            return ordered
                .OrderBy(l => l.Y / band)
                .ThenBy(l => l.X)
                .ToList();
        }

        /// <summary>
        /// Decides whether a document was readable, and whether it is the document
        /// it was submitted as.
        /// </summary>
        /// <remarks>
        /// The two questions are asked in this order on purpose. An unreadable page
        /// cannot be identified either, so reporting "this is not a receipt" for a
        /// photograph that is simply too dark would send the user hunting for a
        /// document they are already holding.
        ///
        /// The landmark check runs on prepared lines rather than raw ones: the CR is
        /// printed sideways on the same sheet as the OR, and its rotated text would
        /// otherwise be searched for receipt landmarks it does not carry.
        /// </remarks>
        public static ScanFailureReason Diagnose(
            IReadOnlyCollection<OcrLineDto> rawLines,
            DocumentType type)
        {
            var readability = Diagnose(rawLines);
            if (readability != ScanFailureReason.None)
                return readability;

            return DocumentLandmarks.LooksGenuine(Prepare(rawLines), type)
                ? ScanFailureReason.None
                : ScanFailureReason.WrongDocument;
        }

        /// <summary>
        /// Decides whether a document was readable at all.
        /// </summary>
        /// <remarks>
        /// Runs on the raw lines, before rotated ones are dropped — the share of
        /// rotated lines is itself the signal that the phone was held sideways.
        ///
        /// This is the one interpretation the phone is not trusted with, and the
        /// only gate that can send a user back to retake. It answers "could we read
        /// it", never "is the document acceptable".
        /// </remarks>
        public static ScanFailureReason Diagnose(IReadOnlyCollection<OcrLineDto> rawLines)
        {
            if (rawLines.Count < MinimumUsableLines)
                return ScanFailureReason.NoText;

            var rotatedShare = rawLines.Count(IsRotated) / (double)rawLines.Count;
            if (rotatedShare > SidewaysLineShare)
                return ScanFailureReason.Sideways;

            var upright = rawLines.Where(l => !IsRotated(l)).ToList();
            if (upright.Count < MinimumUsableLines)
                return ScanFailureReason.NoText;

            if (upright.Average(l => l.Confidence) < BlurryConfidenceThreshold)
                return ScanFailureReason.Blurry;

            return ScanFailureReason.None;
        }

        /// <summary>
        /// Plain-language message for a failure, saying what is wrong and what to do.
        /// </summary>
        public static string MessageFor(ScanFailureReason reason, string documentLabel) => reason switch
        {
            ScanFailureReason.NoText =>
                $"We couldn't find any text on the {documentLabel}. Make sure it fills the frame and the light is good.",
            ScanFailureReason.Sideways =>
                $"Turn your phone so the {documentLabel} reads upright, then take the photo again.",
            ScanFailureReason.Blurry =>
                $"The {documentLabel} is too blurry to read. Hold steady, get closer, and try again.",
            ScanFailureReason.WrongDocument =>
                $"This does not look like the {documentLabel}. Check you photographed the right document, and that all of it is inside the frame.",
            _ => string.Empty
        };
    }
}
