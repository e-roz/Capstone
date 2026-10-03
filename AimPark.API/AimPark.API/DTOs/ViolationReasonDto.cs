namespace AimPark.API.DTOs
{
    /// <summary>
    /// Body for the admin actions that close a case without an appeal —
    /// dismissing it, or marking the user accountable before the deadline.
    /// The reason is required: both bypass the normal process, so the record
    /// has to say why.
    /// </summary>
    public class ViolationReasonDto
    {
        public string Reason { get; set; } = string.Empty;
    }
}
