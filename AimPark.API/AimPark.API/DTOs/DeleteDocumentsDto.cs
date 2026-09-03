namespace AimPark.API.DTOs
{
    /// <summary>
    /// Confirms an irreversible removal of a user's identity documents.
    /// </summary>
    public class DeleteDocumentsDto
    {
        /// <summary>The acting admin's own password, as archiving asks for.</summary>
        public string Password { get; set; } = string.Empty;

        /// <summary>
        /// Why the images are being removed — a request from the user, a
        /// retention period elapsed. Recorded in the audit log, which is the
        /// only thing that will still describe this afterwards.
        /// </summary>
        public string? Reason { get; set; }
    }
}
