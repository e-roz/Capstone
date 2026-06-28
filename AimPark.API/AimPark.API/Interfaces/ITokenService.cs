using AimPark.API.Entities;

namespace AimPark.API.Interfaces
{
    public interface ITokenService
    {
        string GenerateToken(User user, bool registrationOnly = false);
        string GenerateSessionToken(Guid sessionId);
        Guid? GetSessionIdFromToken(string token);
        Guid? GetUserIdFromToken(string token);
    }
}
