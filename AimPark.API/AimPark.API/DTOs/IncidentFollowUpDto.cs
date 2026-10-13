namespace AimPark.API.DTOs
{
    public class AddIncidentFollowUpDto
    {
        public string Note { get; set; } = string.Empty;

        /// <summary>One optional photo or PDF - a gate-log screenshot, a plate.</summary>
        public IFormFile? Attachment { get; set; }
    }

    public class IncidentFollowUpItem
    {
        public Guid FollowUpId { get; set; }
        public string AuthorName { get; set; } = string.Empty;
        public string Note { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public string? AttachmentUrl { get; set; }
        public string? AttachmentName { get; set; }

        /// <summary>An administrator has not opened the report since this was added.</summary>
        public bool IsNew { get; set; }
    }
}
