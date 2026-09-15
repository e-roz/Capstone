namespace AimPark.API.Enums
{
    /// <summary>
    /// The kinds of file collected during registration.
    /// </summary>
    /// <remarks>
    /// Replaces the free-text label this used to be. That field once held "OR" on
    /// rows that were actually the back of a government ID, and nothing in the
    /// database could notice — an enum makes that a compile error instead.
    ///
    /// The CR is not collected: nothing reads it, and the admin already sees the
    /// plate photo and the receipt.
    /// </remarks>
    public enum DocumentType
    {
        /// <summary>School registration/assessment form — proves current enrolment.</summary>
        Raf,

        /// <summary>
        /// School-issued ID, submitted by faculty and staff in place of a RAF.
        /// Not parsed — the admin reviews it by eye.
        /// </summary>
        SchoolId,

        /// <summary>Driver's licence — proves the applicant may legally drive.</summary>
        License,

        /// <summary>LTO Official Receipt — the source of the plate number.</summary>
        OfficialReceipt,

        /// <summary>
        /// Retired — no longer collected. The plate photo used to be cross-checked
        /// against the receipt's plate reading; that check was removed because the
        /// plate is now user-editable and the photo added a document for little
        /// evidence. Kept as an enum member, not deleted, because it is stored as an
        /// integer and old <see cref="Document"/> rows already carry this value —
        /// removing it would renumber nothing after it (it's last), but deleting a
        /// member some rows still reference is never done in this codebase.
        /// </summary>
        PlatePhoto
    }
}
