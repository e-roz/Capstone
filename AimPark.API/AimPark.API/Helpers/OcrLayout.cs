using AimPark.API.DTOs;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Finds a label's value by where it sits on the page rather than by what line
    /// it shares.
    /// </summary>
    /// <remarks>
    /// Forms laid out as tables defeat same-line rules. On a real STI assessment
    /// form, "SY &amp; Term:" and its value "2627/1T" come back as two separate
    /// lines side by side, and "Student No" is a caption printed *underneath* the
    /// number it describes.
    ///
    /// Sorting cannot fix this either: "Year Level:" sits at y=372 while its own
    /// value sits at y=359, so any row-banding scheme drops them into different
    /// bands. The boxes have to be compared directly.
    /// </remarks>
    public static class OcrLayout
    {
        /// <summary>
        /// True when two lines sit on the same printed row.
        /// </summary>
        /// <remarks>
        /// Measured as vertical overlap against the shorter of the two boxes, which
        /// tolerates the baseline drift between cells of different font sizes. On the
        /// sample form the label/value pairs overlap by 76–91%.
        /// </remarks>
        public static bool OnSameRow(OcrLineDto a, OcrLineDto b, double minOverlap = 0.5)
        {
            var top = Math.Max(a.Y, b.Y);
            var bottom = Math.Min(a.Y + a.H, b.Y + b.H);
            var overlap = bottom - top;

            if (overlap <= 0)
                return false;

            var shorter = Math.Min(a.H, b.H);
            return shorter > 0 && overlap / (double)shorter >= minOverlap;
        }

        /// <summary>
        /// The nearest line to the right of <paramref name="label"/> on the same row.
        /// </summary>
        public static OcrLineDto? ValueRightOf(IEnumerable<OcrLineDto> lines, OcrLineDto label)
        {
            var labelRight = label.X + label.W;

            return lines
                .Where(l => !ReferenceEquals(l, label))
                .Where(l => l.X >= labelRight - (label.W / 10))
                .Where(l => OnSameRow(l, label))
                .OrderBy(l => l.X)
                .FirstOrDefault();
        }

        /// <summary>
        /// The line printed directly above <paramref name="label"/>, for captions
        /// that sit beneath their value.
        /// </summary>
        /// <remarks>
        /// Requires the two boxes to share horizontal space, so a caption in one
        /// column never picks up the value from the column beside it. The vertical
        /// gap is capped at twice the label's height — on the sample form the real
        /// gaps were 17 to 30 pixels against label heights of 35 to 42.
        /// </remarks>
        public static OcrLineDto? ValueAbove(IEnumerable<OcrLineDto> lines, OcrLineDto label)
        {
            var maxGap = label.H * 2;

            return lines
                .Where(l => !ReferenceEquals(l, label))
                .Where(l => l.Y + l.H <= label.Y)
                .Where(l => label.Y - (l.Y + l.H) <= maxGap)
                .Where(l => HorizontalOverlap(l, label) >= label.W * 0.5)
                .OrderByDescending(l => l.Y)
                .FirstOrDefault();
        }

        /// <summary>
        /// Finds the line carrying a label, allowing for OCR damage to its text.
        /// </summary>
        /// <remarks>
        /// The sample form returned "SY &amp; Tem:" for "SY &amp; Term:", so some
        /// tolerance is essential. But taking the first line that comes within
        /// tolerance is not safe: searching for "Student No" on that same form, the
        /// heading "Student Information" is close enough to qualify and appears
        /// first, which sends the caller hunting for a value above the wrong line.
        ///
        /// The closest match wins instead, so an exact label always beats a mangled
        /// coincidence.
        /// </remarks>
        public static OcrLineDto? FindLabel(IEnumerable<OcrLineDto> lines, string label)
            => lines
                .Select(l => (Line: l, Distance: FuzzyText.LabelDistance(l.Text, label)))
                .Where(candidate => candidate.Distance != int.MaxValue)
                .OrderBy(candidate => candidate.Distance)
                .Select(candidate => candidate.Line)
                .FirstOrDefault();

        private static int HorizontalOverlap(OcrLineDto a, OcrLineDto b)
        {
            var left = Math.Max(a.X, b.X);
            var right = Math.Min(a.X + a.W, b.X + b.W);
            return Math.Max(0, right - left);
        }

        /// <summary>
        /// Value for a label, wherever the form happens to put it: on the same line,
        /// beside it, or above it.
        /// </summary>
        public static string? ValueFor(
            IReadOnlyList<OcrLineDto> lines,
            string label,
            bool captionBelowValue = false)
        {
            var labelLine = FindLabel(lines, label);
            if (labelLine is null)
                return null;

            if (captionBelowValue)
                return FuzzyText.TrimValue(ValueAbove(lines, labelLine)?.Text);

            // Same line first — some fields really do print the value after the
            // label — then the cell to the right.
            var after = FuzzyText.IndexAfterLabel(labelLine.Text, label);
            var inline = FuzzyText.TrimValue(labelLine.Text[after..]);
            if (inline.Length > 1)
                return inline;

            return FuzzyText.TrimValue(ValueRightOf(lines, labelLine)?.Text);
        }
    }
}
