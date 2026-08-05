using System.Globalization;
using System.Security.Claims;
using System.Text.Encodings.Web;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace AimPark.API.Auth
{
    /// <summary>
    /// Authenticates gate hardware by a long-lived key in the
    /// <c>X-Api-Key</c> header, sitting alongside JWT bearer auth rather than
    /// replacing it — people still log in normally.
    ///
    /// The resulting principal carries the device's gate, so entry logs are
    /// tagged from the hardware's own identity rather than from anything the
    /// request body claims. A reader bolted to Gate 1 cannot report Gate 2.
    /// </summary>
    public class ApiKeyAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
    {
        private readonly IGateDeviceService _gateDevices;

        public ApiKeyAuthenticationHandler(
            IOptionsMonitor<AuthenticationSchemeOptions> options,
            ILoggerFactory logger,
            UrlEncoder encoder,
            IGateDeviceService gateDevices)
            : base(options, logger, encoder)
        {
            _gateDevices = gateDevices;
        }

        protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!Request.Headers.TryGetValue(ApiKeyDefaults.HeaderName, out var provided))
                return AuthenticateResult.NoResult(); // Let another scheme try.

            var apiKey = provided.ToString();
            if (string.IsNullOrWhiteSpace(apiKey))
                return AuthenticateResult.NoResult();

            var device = await _gateDevices.AuthenticateAsync(apiKey, Context.RequestAborted);
            if (device is null)
            {
                Logger.LogWarning("Rejected gate device key from {RemoteIp}.",
                    Context.Connection.RemoteIpAddress);
                return AuthenticateResult.Fail("Invalid or revoked device key.");
            }

            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, device.Id.ToString()),
                new Claim(ClaimTypes.Name, device.Name),
                new Claim(ClaimTypes.Role, ApiKeyDefaults.DeviceRole),
                new Claim(ApiKeyDefaults.GateClaim, device.Gate.ToString(CultureInfo.InvariantCulture))
            };

            var identity = new ClaimsIdentity(claims, ApiKeyDefaults.AuthenticationScheme);
            var principal = new ClaimsPrincipal(identity);

            return AuthenticateResult.Success(
                new AuthenticationTicket(principal, ApiKeyDefaults.AuthenticationScheme));
        }
    }
}
