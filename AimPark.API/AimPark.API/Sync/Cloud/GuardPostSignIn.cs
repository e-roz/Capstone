using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace AimPark.API.Sync.Cloud
{
    /// <summary>
    /// Once the guard post's server is live, Security accounts sign in there
    /// and not on the cloud's admin panel.
    /// </summary>
    /// <remarks>
    /// Gate work only happens at the guard post after the switch-over, so a
    /// guard signed in to the cloud panel would find every gate action refused.
    /// Turning them away at the door, with the address to use, is clearer than
    /// letting them in to a panel that half works.
    ///
    /// Checked at sign-in only, never on each request: the guard post forwards
    /// a guard's notification calls to the cloud with the token it issued, and
    /// those must keep working.
    ///
    /// Tied to <see cref="SiteOptions.CloudGateEndpointsEnabled"/>, so setting
    /// that back to true (the guard PC is down) also lets guards back in here.
    /// </remarks>
    public class GuardPostSignIn
    {
        private readonly SiteOptions _options;

        public GuardPostSignIn(IOptions<SiteOptions> options)
        {
            _options = options.Value;
        }

        /// <returns>A 403 to send back instead of a token, or null to carry on.</returns>
        public ObjectResult? RefuseIfGuard(User user)
        {
            if (!_options.IsCloud || _options.CloudGateEndpointsEnabled || user.Role != UserRole.Security)
                return null;

            var where = string.IsNullOrWhiteSpace(_options.GuardPanelUrl)
                ? "on the guard post's computer"
                : $"at {_options.GuardPanelUrl}";

            return new ObjectResult(new
            {
                message = $"Security accounts sign in at the guard post: {where}.",
                guardPanelUrl = _options.GuardPanelUrl
            })
            { StatusCode = StatusCodes.Status403Forbidden };
        }
    }
}
