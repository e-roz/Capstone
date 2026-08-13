using AimPark.API.Enums;

namespace AimPark.API.DTOs
{
    /// <summary>
    /// What the phone's text recognition returned for one document.
    /// </summary>
    /// <remarks>
    /// Rides in the same multipart POST as the image it describes. A separate
    /// follow-up call would open a window in which the stored image and the OCR
    /// result could disagree, and no reviewer could resolve which was true.
    /// </remarks>
    public class OcrPayloadDto
    {
        public DocumentType DocumentType { get; set; }

        /// <summary>
        /// Pixel size of the image the boxes were measured against. Mandatory —
        /// without it the rules reason in one handset's pixels and every spatial
        /// comparison breaks on a phone with a different camera.
        /// </summary>
        public int ImageWidth { get; set; }
        public int ImageHeight { get; set; }

        public List<OcrLineDto> Lines { get; set; } = [];
    }

    /// <summary>
    /// One recognised line of text and where it sat on the page.
    /// </summary>
    /// <remarks>
    /// Line level, not block or word. Blocks put a whole paragraph in one box and
    /// lose the geometry needed to read a value outward from its label; words
    /// explode the payload and throw away reading order within a line.
    /// </remarks>
    public class OcrLineDto
    {
        public string Text { get; set; } = string.Empty;

        public int X { get; set; }
        public int Y { get; set; }
        public int W { get; set; }
        public int H { get; set; }

        /// <summary>
        /// 0–1. Observed roughly 0.90 on a clean line and 0.31 on junk, which makes
        /// a low average across a document a dependable blur signal.
        /// </summary>
        public double Confidence { get; set; }
    }
}
