namespace AimPark.API.DTOs
{
    public class CompleteProfileDto
    {
        public string FullName { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }

        // Must be true to proceed. Recorded on the user as TermsAcceptedAt so
        // there is an auditable record of consent rather than an assumption.
        public bool AcceptedTerms { get; set; }
    }
}
