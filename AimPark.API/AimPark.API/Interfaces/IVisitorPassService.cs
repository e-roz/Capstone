using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IVisitorPassService
    {
        Task<ActionResult<VisitorPassResponse>> IssueAsync(
            IssueVisitorPassDto dto, Guid issuedByUserId, CancellationToken ct);

        Task<ActionResult<VisitorPassListResponse>> ListAsync(
            string? status, int page, int pageSize, CancellationToken ct);

        /// <summary>Takes the card back and frees it for the next visitor.</summary>
        Task<ActionResult<object>> ReturnAsync(Guid passId, CancellationToken ct);

        /// <summary>
        /// Who a card belongs to and what should be attached to it — the guard's
        /// side of dual-factor verification.
        /// </summary>
        Task<ActionResult<TagLookupResponse>> LookupTagAsync(string rfidTagId, CancellationToken ct);
    }
}
