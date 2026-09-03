namespace AimPark.API.DTOs
{
    /// <summary>What the enrollment reader posts when a card is tapped.</summary>
    public class RfidScanDto
    {
        public string RfidTagId { get; set; } = string.Empty;
    }

    /// <summary>
    /// The reader's answer. <c>Result</c> is the contract — firmware branches on
    /// it to pick a light and a beep; <c>Message</c> is for humans and its
    /// wording will change.
    /// </summary>
    public class RfidScanResponse
    {
        /// <summary>FREE, IN_USE or INVALID_TAG.</summary>
        public string Result { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;

        /// <summary>The normalized UID, so serial output matches what was stored.</summary>
        public string RfidTagId { get; set; } = string.Empty;
    }

    /// <summary>
    /// The most recent tap, polled by the admin panel while its Assign dialog
    /// is open. Null when nothing has been tapped recently.
    /// </summary>
    public class RfidLastScanResponse
    {
        /// <summary>
        /// Changes on every tap. The panel watches this rather than the UID so
        /// that tapping the same card twice still reads as a fresh scan.
        /// </summary>
        public Guid ScanId { get; set; }

        public string RfidTagId { get; set; } = string.Empty;
        public DateTime ScannedAt { get; set; }

        /// <summary>Which reader saw it, for when more than one desk exists.</summary>
        public string DeviceName { get; set; } = string.Empty;

        /// <summary>
        /// Already on someone's account. The panel warns before the admin
        /// assigns, rather than letting the save fail.
        /// </summary>
        public bool IsAssigned { get; set; }

        public Guid? AssignedToUserId { get; set; }
        public string? AssignedToName { get; set; }
    }
}
