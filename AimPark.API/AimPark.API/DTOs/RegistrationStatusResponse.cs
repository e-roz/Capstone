namespace AimPark.API.DTOs
{
    /// <summary>
    /// Why an account cannot sign in yet, and what it is waiting on.
    /// </summary>
    /// <remarks>
    /// The three status fields are strings holding the enum member *name*, not
    /// the enums themselves, and that is load-bearing rather than stylistic.
    ///
    /// Nothing registers a <c>JsonStringEnumConverter</c>, so a property typed
    /// as an enum serialises as its ordinal. This DTO was the only one left
    /// holding raw enum types — every other response stringifies, and both
    /// clients read these as names. So the apps received <c>"accountStatus": 0</c>
    /// where they expected <c>"PendingReview"</c>, matched none of the cases
    /// they knew, and fell through to their default: an account waiting for
    /// approval was told it had been suspended.
    ///
    /// Keep these as strings. Typing them back to the enums would silently
    /// reintroduce exactly that.
    /// </remarks>
    public class RegistrationStatusResponse
    {
        public string RegistrationStep { get; set; } = string.Empty;
        public string AccountStatus { get; set; } = string.Empty;
        public string VerificationStatus { get; set; } = string.Empty;
        public string? RejectionReason { get; set; }
        public DateTime? CanReapplyAt { get; set; }

        /// <summary>
        /// What the profile step recorded, so the app can show it back.
        /// </summary>
        /// <remarks>
        /// Here because the profile step can now be revisited from the first
        /// document screen, and the app has nothing of its own to prefill from:
        /// completing the profile clears the local registration draft, and an
        /// app relaunched mid-registration never had it. Without these, going
        /// back would present an empty form and overwrite a good name with
        /// whatever was typed into it.
        ///
        /// A string for the same reason as the three above.
        /// </remarks>
        public string FullName { get; set; } = string.Empty;

        public string Affiliation { get; set; } = string.Empty;

        /// <summary>
        /// Documents a reviewer has asked for again. Empty in the ordinary case.
        /// </summary>
        /// <remarks>
        /// What turns a generic "upload your documents" step into a specific
        /// request. The app asks for exactly these and shows each reason on the
        /// capture screen it belongs to, so the applicant retakes one photograph
        /// knowing what was wrong with it rather than all four knowing nothing.
        /// </remarks>
        public List<DocumentRetakeItemDto> DocumentsToRetake { get; set; } = [];
    }
}
