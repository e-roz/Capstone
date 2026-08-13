namespace AimPark.API.Enums
{
    /// <summary>
    /// Why a document could not be read, or that it could.
    /// </summary>
    /// <remarks>
    /// These separate the two failure kinds that must never be conflated:
    /// "we cannot read it", where retaking the photo helps, and "we read it and
    /// there is a problem", where retaking helps nothing. Telling someone with a
    /// lapsed registration that their photo is blurry sends them into an endless
    /// retake loop.
    ///
    /// Only the first group appears here. The second is a check result, not a
    /// reading failure.
    /// </remarks>
    public enum ScanFailureReason
    {
        /// <summary>Read well enough to continue.</summary>
        None,

        /// <summary>Almost no text found — not a document, or too dark.</summary>
        NoText,

        /// <summary>Most lines are rotated; the phone was held the wrong way.</summary>
        Sideways,

        /// <summary>Plenty of lines, but confidence across them is low.</summary>
        Blurry
    }
}
