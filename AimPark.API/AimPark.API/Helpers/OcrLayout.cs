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
        /// <remarks>
        /// Both limits are optional so the school form keeps its old behaviour.
        /// <paramref name="maxGap"/> stops the search running across the page: on an
        /// LTO receipt a "Vehicle Type:" whose value did not read would otherwise
        /// pick up "Registration" from the fee table 600 pixels away and call the
        /// vehicle a car. <paramref name="neighbourLabels"/> makes the search stop,
        /// rather than skip, when the nearest line is another field's caption.
        /// </remarks>
        public static OcrLineDto? ValueRightOf(
            IEnumerable<OcrLineDto> lines,
            OcrLineDto label,
            int? maxGap = null,
            IReadOnlyCollection<string>? neighbourLabels = null)
        {
            var labelRight = label.X + label.W;

            var nearest = lines
                .Where(l => !ReferenceEquals(l, label))
                .Where(l => l.X >= labelRight - (label.W / 10))
                .Where(l => OnSameRow(l, label))
                .OrderBy(l => l.X)
                .FirstOrDefault();

            if (nearest is null)
                return null;

            if (maxGap is int gap && nearest.X - labelRight > gap)
                return null;

            return neighbourLabels is not null && IsLabelLine(nearest, neighbourLabels)
                ? null
                : nearest;
        }

        /// <summary>
        /// The line printed directly below <paramref name="label"/>, for captions
        /// that sit above their value.
        /// </summary>
        /// <remarks>
        /// A Philippine licence prints "License No.", "Expiration Date" and "Agency
        /// Code" side by side, with their values one row down. Reading order puts the
        /// three captions next to each other, so "the next line" after a caption is
        /// another caption. Comparing boxes finds the value instead.
        ///
        /// "Below" means the line's middle is under the label's bottom edge. The tops
        /// are not compared: on real licences the value's box starts 4 to 12 pixels
        /// inside the caption's. The gap is capped at twice the label's height, as
        /// for <see cref="ValueAbove"/>.
        ///
        /// The boxes must share at least half the narrower one's width, so a value
        /// under one column is never credited to the caption beside it. One OCR line
        /// can sit under two captions at once: the licence number and expiry often
        /// come back as one line. That is deliberate; the caller separates them by
        /// pattern.
        ///
        /// When the nearest line below is itself a caption, the value is missing,
        /// and the search stops there rather than continuing into the next field.
        /// </remarks>
        public static OcrLineDto? ValueBelow(
            IEnumerable<OcrLineDto> lines,
            OcrLineDto label,
            IReadOnlyCollection<string>? neighbourLabels = null)
        {
            var labelBottom = label.Y + label.H;
            var maxGap = label.H * 2;

            var nearest = lines
                .Where(l => !ReferenceEquals(l, label))
                .Where(l => l.Y + (l.H / 2) > labelBottom)
                .Where(l => l.Y - labelBottom <= maxGap)
                .Where(l => HorizontalOverlap(l, label) >= Math.Min(l.W, label.W) * 0.5)
                .OrderBy(l => l.Y)
                .FirstOrDefault();

            if (nearest is null)
                return null;

            return neighbourLabels is not null && IsLabelLine(nearest, neighbourLabels)
                ? null
                : nearest;
        }

        /// <summary>
        /// True when the line is a caption from <paramref name="labels"/> rather than
        /// a value.
        /// </summary>
        /// <remarks>
        /// The caption has to be most of the line. A value that merely contains a
        /// caption word — "Color: MATTE ORANGE/BLACK" holds "Color" — is still a
        /// value.
        /// </remarks>
        public static bool IsLabelLine(OcrLineDto line, IEnumerable<string> labels)
        {
            var text = FuzzyText.TrimValue(line.Text);

            return labels.Any(label =>
                text.Length <= label.Length + 3
                && FuzzyText.LabelDistance(text, label) != int.MaxValue);
        }

        /// <summary>
        /// The line carrying the first of <paramref name="labels"/> that appears,
        /// trying each spelling in order.
        /// </summary>
        public static OcrLineDto? FindAnyLabel(IEnumerable<OcrLineDto> lines, IEnumerable<string> labels)
        {
            var all = lines as IReadOnlyCollection<OcrLineDto> ?? lines.ToList();

            foreach (var label in labels)
            {
                var found = FindLabel(all, label);
                if (found is not null)
                    return found;
            }

            return null;
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
        /// <remarks>
        /// <paramref name="maxRightGapInHeights"/> and
        /// <paramref name="neighbourLabels"/> pass through to
        /// <see cref="ValueRightOf"/>. The school form does not use them.
        /// </remarks>
        public static string? ValueFor(
            IReadOnlyList<OcrLineDto> lines,
            string label,
            bool captionBelowValue = false,
            double? maxRightGapInHeights = null,
            IReadOnlyCollection<string>? neighbourLabels = null)
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

            int? maxGap = maxRightGapInHeights is double heights
                ? (int)(labelLine.H * heights)
                : null;

            return FuzzyText.TrimValue(
                ValueRightOf(lines, labelLine, maxGap, neighbourLabels)?.Text);
        }
    }
}
