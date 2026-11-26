using System.Text.RegularExpressions;
using AimPark.API.Helpers;
using Microsoft.AspNetCore.Mvc;
using QuestPDF.Fluent;

namespace AimPark.API.Reports
{
    /// <summary>
    /// Everything one report contributes: its name, what it covers, the
    /// figures the verify page keeps, and how to draw its body. The frame
    /// (header, signatures, footer, QR) is the same for all and lives in
    /// <see cref="PdfLayout"/>.
    /// </summary>
    public record ReportContent(
        string Title,
        string FileStem,
        string SecondSignatureCaption,
        string PeriodText,
        DateOnly? From,
        DateOnly? To,
        IReadOnlyList<KeyFigure> KeyFigures,
        Action<ColumnDescriptor> Body);

    public interface IPdfReport
    {
        /// <summary>The URL segment: summary, collections, violations, entry-exit, incidents, vehicles.</summary>
        string Kind { get; }

        Task<ReportContent> BuildAsync(ReportQuery query, CancellationToken ct);
    }

    /// <summary>A request the report cannot answer as asked, such as too long a range for a log.</summary>
    public class ReportRequestException(string message) : Exception(message);

    internal static partial class ReportText
    {
        /// <summary>"SuspiciousActivity" → "Suspicious activity".</summary>
        public static string Humanize(object value)
        {
            var spaced = CamelBreak().Replace(value.ToString() ?? "", " $1").Trim();
            return spaced.Length == 0 ? spaced : spaced[0] + spaced[1..].ToLowerInvariant();
        }

        /// <summary>What each case stage means, in words a reader of the paper will follow.</summary>
        public static string ViolationStatus(Enums.ViolationStatus s) => s switch
        {
            Enums.ViolationStatus.Issued => "Issued, appeal window open",
            Enums.ViolationStatus.PendingAppeal => "Appeal waiting for decision",
            Enums.ViolationStatus.Accountable => "Accountable (fine owed)",
            Enums.ViolationStatus.Appealed => "Appeal won (no penalty)",
            Enums.ViolationStatus.Dismissed => "Dismissed",
            _ => Humanize(s)
        };

        public static string Clip(string? text, int max) =>
            string.IsNullOrWhiteSpace(text) ? "—"
            : text.Length <= max ? text.Trim()
            : text[..(max - 1)].TrimEnd() + "…";

        public static string Duration(TimeSpan span)
        {
            if (span.TotalMinutes < 1) return "<1m";
            var h = (int)span.TotalHours;
            return h > 0 ? $"{h}h {span.Minutes}m" : $"{span.Minutes}m";
        }

        /// <summary>Reads the value out of a service result that returned Ok(...).</summary>
        public static T Ok<T>(ActionResult<T> result) =>
            result.Value ?? (T)((ObjectResult)result.Result!).Value!;

        [GeneratedRegex("(?<=[a-z])([A-Z])")]
        private static partial Regex CamelBreak();
    }
}
