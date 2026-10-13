using AimPark.API.DTOs;

namespace AimPark.API.Interfaces
{
    public interface IInvestigationService
    {
        /// <summary>People, visitors, unclaimed cards and unregistered plates that match what was typed.</summary>
        Task<SearchResponse> SearchAsync(string? typed, CancellationToken ct);

        /// <summary>
        /// Everything held about one subject, named by exactly one of the
        /// arguments. Null when there is nothing to show.
        /// </summary>
        Task<InvestigationProfile?> ProfileAsync(
            Guid? userId, Guid? visitorPassId, string? card, string? plate, CancellationToken ct);
    }
}
