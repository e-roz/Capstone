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

        /// <summary>The photo shows the plate the receipt names.</summary>
        Agreed,

        /// <summary>The photo shows a readable plate, and it is a different one.</summary>
        Differs
    }
}
