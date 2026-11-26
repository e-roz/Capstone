namespace AimPark.API.Entities
{
    /// <summary>
    /// One PDF report the system produced: its number, who made it, and the
    /// figures it showed at that moment.
    /// </summary>
    /// <remarks>
    /// A printed report can be edited by anyone with a PDF editor. This row is
    /// what the copy is checked against: the QR code on every page opens a
    /// public page showing <see cref="KeyFiguresJson"/> as recorded here, so a
    /// figure changed on the paper no longer matches the system.
    ///
    /// The figures are a snapshot, not a recomputation. A payment that lands
    /// after the report was made would otherwise make an honest printout look
    /// forged.
    /// </remarks>
    public class GeneratedReport
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        /// <summary>RPT-yyyy-MM-nnnn, counting from 1 each month.</summary>
        public string Number { get; set; } = string.Empty;

        /// <summary>summary, collections, violations, entry-exit, incidents, vehicles.</summary>
        public string Kind { get; set; } = string.Empty;

        public string Title { get; set; } = string.Empty;

        /// <summary>Philippine days covered. Null on a report that is "as of" a moment.</summary>
        public DateOnly? PeriodFrom { get; set; }
        public DateOnly? PeriodTo { get; set; }

        /// <summary>No FK, like the audit tables: the record outlives the account.</summary>
        public Guid GeneratedByUserId { get; set; }
        public string GeneratedByName { get; set; } = string.Empty;

        public DateTime GeneratedAt { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// The secret part of the verify link. Report numbers run in order and
        /// are easy to guess; this is not, so the public page cannot be walked.
        /// </summary>
        public string VerifyToken { get; set; } = string.Empty;

        /// <summary>
        /// The headline figures the report printed, as a JSON array of
        /// <c>{ "label": "...", "value": "..." }</c>. Totals only, never names.
        /// </summary>
        public string KeyFiguresJson { get; set; } = "[]";
    }
}
