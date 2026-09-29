using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    /// <summary>
    /// The bridge between a card tapped on the enrollment reader and the admin
    /// who is about to assign it, so nobody types a UID by hand.
    /// </summary>
    public interface IRfidEnrollmentService
    {
        /// <summary>Records a tap from a reader and tells it whether the card is free.</summary>
        Task<ActionResult<RfidScanResponse>> RecordScanAsync(
            RfidScanDto dto, Guid deviceId, string deviceName, CancellationToken ct);

        /// <summary>
        /// The most recent tap, or null when there is none within the freshness
        /// window. Polled by the panel while its Assign dialog is open.
        /// </summary>
        Task<ActionResult<RfidLastScanResponse?>> GetLastScanAsync(CancellationToken ct);

        /// <summary>
        /// Who holds a card the panel read itself, off a reader plugged into
        /// the admin's own computer. Nothing is buffered.
        /// </summary>
        Task<ActionResult<RfidLastScanResponse>> LookupAsync(string? rfidTagId, CancellationToken ct);
    }
}
