using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IRenewalService
    {
        /// <summary>Reads a renewed licence or registration and returns the date it shows, to be checked.</summary>
        Task<ActionResult<RenewalScanResponse>> ScanAsync(RenewalUploadDto dto, Guid userId, CancellationToken ct);

        /// <summary>Sends a scanned renewal to the admin with the date the user confirmed.</summary>
        Task<ActionResult<object>> SubmitAsync(Guid renewalId, SubmitRenewalDto dto, Guid userId, CancellationToken ct);

        /// <summary>The user's renewals that are waiting or were turned down.</summary>
        Task<ActionResult<List<RenewalResponse>>> GetMineAsync(Guid userId, CancellationToken ct);

        Task<ActionResult<List<AdminRenewalResponse>>> GetForAdminAsync(string? status, CancellationToken ct);
        Task<ActionResult<object>> ApproveAsync(Guid renewalId, Guid adminUserId, CancellationToken ct);
        Task<ActionResult<object>> RejectAsync(Guid renewalId, Guid adminUserId, RejectRenewalDto dto, CancellationToken ct);
    }
}
