using AimPark.API.DTOs;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Whether a finished application can skip the review queue.
    /// </summary>
    /// <remarks>
    /// Pure and stateless, like <see cref="RegistrationChecks"/> — it decides from
    /// the panel the reviewer would have read, so a case the system lets through
    /// is one a reviewer would have seen nothing wrong with.
    ///
    /// "Clear" already means every check passed and none was unreadable or close
    /// to expiring. On top of that, any edit to an identity field (name, student
    /// number, licence name, plate) sends it to a person: a value the applicant
    /// typed proves nothing about who they are.
    ///
    /// A share of clean applications is still routed to a reviewer at random, so
    /// that nobody can rely on a clean-looking set going unseen.
    /// </remarks>
    public static class AutoApprovalPolicy
    {
        /// <summary>Per hundred clean applications, how many still get a human look.</summary>
        public const int SpotCheckPercent = 20;

        public static bool IsClean(RegistrationChecksResponse? checks) =>
            checks is { Verdict: RegistrationChecks.ClearVerdict }
            && !checks.Edits.Any(e => e.IsIdentity);

        /// <param name="identifiersPresent">
        /// Whether the licence number (and, for students, the student number) ended
        /// up on the submission. The duplicate check can only protect an identifier
        /// that exists; a blank is not a pass.
        /// </param>
        /// <param name="roll">0–99. Below <see cref="SpotCheckPercent"/> means "spot-check this one".</param>
        public static bool ShouldAutoApprove(
            RegistrationChecksResponse? checks, bool identifiersPresent, int roll) =>
            identifiersPresent && IsClean(checks) && roll >= SpotCheckPercent;
    }
}
