using AimPark.API.Entities;

namespace AimPark.API.Interfaces
{
    /// <summary>
    /// Turns a submission's readings and confirmations into per-check verdicts and a
    /// summary for the reviewer.
    /// </summary>
    public interface IPreScreeningService
    {
        /// <summary>
        /// Fills in the check results, notes, and overall outcome on the submission.
        /// </summary>
        /// <remarks>
        /// Never approves anything. Passing every check proves the photos were
        /// readable and internally consistent — not that the documents are genuine or
        /// that they belong to the applicant. The best outcome available here is
        /// "nothing looks wrong", and a person still decides.
        /// </remarks>
        void Evaluate(DocumentVerification verification, User user, Vehicle? vehicle);
    }
}
