namespace AimPark.API.Entities
{
    /// <summary>
    /// An unhandled failure, captured so it can be looked at after the fact —
    /// the document's "System Error Logs: captures system errors or failed
    /// processes (e.g. failed RFID scans or registration errors)".
    ///
    /// Written by the global exception handler, which is also what stops an
    /// unhandled 500 from reaching the browser with no CORS headers on it and
    /// being reported as a phantom CORS error.
    /// </summary>
    public class SystemErrorLog
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        /// <summary>Exception type name, e.g. "NpgsqlException".</summary>
        public string ErrorType { get; set; } = string.Empty;

        public string Message { get; set; } = string.Empty;

        /// <summary>
        /// Truncated before storing. A stack trace can run to tens of kilobytes
        /// and the first frames are the ones that identify the fault; keeping
        /// the whole thing would let one crash loop fill the table.
        /// </summary>
        public string? StackTrace { get; set; }

        /// <summary>Request that failed, e.g. "POST /api/parking/entry".</summary>
        public string? Path { get; set; }

        public int StatusCode { get; set; }

        /// <summary>Who was signed in when it happened, when anyone was.</summary>
        public Guid? UserId { get; set; }

        /// <summary>
        /// Matches the `traceId` returned to the caller in the error body, so a
        /// tester who screenshots an error can be tied to the row that explains
        /// it without guessing from timestamps.
        /// </summary>
        public string? TraceId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
