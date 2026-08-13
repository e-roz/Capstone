namespace AimPark.API.Enums
{
    /// <summary>
    /// Outcome of one automated check inside a document submission.
    /// </summary>
    /// <remarks>
    /// <see cref="NotChecked"/> is not a soft failure — it means a value the check
    /// needed was never read, so the check could not form an opinion. It is the
    /// reason a submission lands in manual review rather than being rejected.
    /// </remarks>
    public enum CheckResult
    {
        NotChecked,
        Passed,
        Failed
    }
}
