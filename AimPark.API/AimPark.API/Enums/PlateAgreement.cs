namespace AimPark.API.Enums
{
    /// <summary>
    /// Whether the plate photographed on the vehicle is the plate the receipt names.
    /// </summary>
    /// <remarks>
    /// This is the check that carries the plate now. The applicant no longer types a
    /// plate anywhere, so the only evidence that the record is right is two
    /// independent readings of the same characters — one off the receipt's print, one
    /// off the metal — agreeing with each other.
    ///
    /// The three outcomes need different words on screen, which is why "no plate
    /// found in the photo" is not folded in with "a different plate was found". The
    /// first asks for a better photograph; the second says the receipt may belong to
    /// another vehicle, and no retake will change that.
    /// </remarks>
    public enum PlateAgreement
    {
        /// <summary>
        /// One of the two readings is missing, so there was nothing to compare. Not a
        /// failure — it reaches a reviewer rather than being held against anyone.
        /// </summary>
        NotChecked,

        /// <summary>The photo shows exactly the plate the receipt names.</summary>
        Agreed,

        /// <summary>
        /// The photo shows a plate one character away from the receipt's.
        /// </summary>
        /// <remarks>
        /// Split out from <see cref="Agreed"/> because the plate is shown read-only
        /// and goes straight onto the vehicle record: one character of slack was
        /// absorbing the exact error that matters most. A receipt misread as
        /// "A8C 1234" against metal reading "ABC 1234" is one edit apart, so it used
        /// to pass, and the wrong plate then sat in the database until someone was
        /// turned away at the gate holding a valid card with nothing to explain why.
        ///
        /// The slack itself is still right — these are outdoor photographs at an
        /// angle — so this is not a failure. It is the one case where the applicant
        /// is asked to look at the two readings and say which is correct, because
        /// they are holding both the receipt and the vehicle.
        /// </remarks>
        NearMatch,

        /// <summary>The photo shows a readable plate, and it is a different one.</summary>
        Differs
    }
}
