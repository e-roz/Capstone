using AimPark.API.DTOs;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IRegistrationService
    {
        Task<ActionResult<SessionResponse>> InitiatePhoneAsync(InitiatePhoneDto dto, CancellationToken ct);
        Task<ActionResult<SessionResponse>> VerifyPhoneAsync(VerifyOtpDto dto, string? sessionToken, CancellationToken ct);
        Task<ActionResult<SessionResponse>> InitiateEmailAsync(InitiateEmailDto dto, string? sessionToken, CancellationToken ct);
        Task<ActionResult<SessionResponse>> VerifyEmailAsync(VerifyOtpDto dto, string? sessionToken, CancellationToken ct);
        Task<ActionResult<SessionResponse>> ResendOtpAsync(ResendOtpDto dto, string? sessionToken, CancellationToken ct);
        Task<ActionResult<CompleteProfileResponse>> CompleteProfileAsync(CompleteProfileDto dto, string? sessionToken, CancellationToken ct);
        Task<ActionResult<object>> RegisterVehicleAsync(VehicleDTO dto, Guid userId, CancellationToken ct);
        Task<ActionResult<object>> RegisterDocumentsAsync(DocumentUploadDTO dto, Guid userId, CancellationToken ct);
        Task<ActionResult<ReapplyResponse>> ReapplyAsync(Guid userId, CancellationToken ct);
        Task<ActionResult<RegistrationStatusResponse>> GetStatusAsync(Guid userId, CancellationToken ct);
        Task<ActionResult<OAuthCallbackResponse>> HandleOAuthCallbackAsync(AuthProvider provider, string email, string externalId, string? fullName, CancellationToken ct);
    }
}
