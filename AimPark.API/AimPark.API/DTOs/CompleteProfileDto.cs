namespace AimPark.API.DTOs
{
    public class CompleteProfileDto
    {
        public string FullName { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;

        /// <summary>
        /// Student, Faculty, or Staff. Decides which documents the upload step asks
        /// for — a RAF for students, a school ID for everyone else. Defaults to
        /// Student when absent.
        /// </summary>
        public string? Affiliation { get; set; }

        // Must be true to proceed. Recorded on the user as TermsAcceptedAt so
        // there is an auditable record of consent rather than an assumption.
        public bool AcceptedTerms { get; set; }
    }
}
