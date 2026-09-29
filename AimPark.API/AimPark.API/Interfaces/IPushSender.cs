using AimPark.API.Enums;

namespace AimPark.API.Interfaces
{
    public interface IPushSender
    {
        /// <summary>
        /// Sends a push to every registered device of every user matching <paramref name="targetRole"/>
        /// (null = all roles). Never throws — push delivery is best-effort and must not
        /// fail the request that triggered it.
        /// </summary>
        Task SendToRoleAsync(UserRole? targetRole, string title, string body, IDictionary<string, string>? data, CancellationToken ct);

        /// <summary>
        /// Sends a push to one specific user's devices. Never throws.
        /// </summary>
        Task SendToUserAsync(Guid userId, string title, string body, IDictionary<string, string>? data, CancellationToken ct);

        /// <summary>
        /// Sends a push to everyone who asked to hear when a bay frees up, except
        /// anyone who has since parked, and uses their watch up. Never throws.
        /// </summary>
        Task SendToSlotWatchersAsync(string title, string body, IDictionary<string, string>? data, CancellationToken ct);
    }
}
