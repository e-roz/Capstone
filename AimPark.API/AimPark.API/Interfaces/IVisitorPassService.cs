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

        /// <summary>
        /// Ends a pass whose car never went in, with the card back in hand.
        /// A visitor who drove in is released by their exit tap instead.
        /// </summary>
        Task<ActionResult<object>> ReturnAsync(Guid passId, Guid takenBackByUserId, CancellationToken ct);

        /// <summary>
        /// The guard confirming a card released at the exit is back in the drawer.
        /// </summary>
        Task<ActionResult<object>> ConfirmCardReturnedAsync(Guid passId, Guid confirmedByUserId, CancellationToken ct);

        /// <summary>
        /// Who a card belongs to and what should be attached to it — the guard's
        /// side of dual-factor verification.
        /// </summary>
        Task<ActionResult<TagLookupResponse>> LookupTagAsync(string rfidTagId, CancellationToken ct);
    }
}
