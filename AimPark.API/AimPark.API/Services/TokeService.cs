using AimPark.API.Entities;
using AimPark.API.Interfaces;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace AimPark.API.Services;

public class TokenService : ITokenService
{
    private readonly IConfiguration _config;

    public TokenService(IConfiguration config)
    {
        _config = config;
    }

    public string GenerateToken(User user, bool registrationOnly = false)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, user.Role.ToString()),
            new("registrationStep", user.RegistrationStep.ToString()),
            new("accountStatus", user.AccountStatus.ToString())
        };

        if (registrationOnly || user.RegistrationStep != Enums.RegistrationStep.Completed)
            claims.Add(new Claim("registration_only", "true"));

        return WriteToken(claims);
    }

    public string GenerateSessionToken(Guid sessionId)
    {
        var claims = new List<Claim>
        {
            new("session_id", sessionId.ToString()),
            new("token_type", "registration_session")
        };

        return WriteToken(claims, expiryMinutes: 24 * 60);
    }

    public Guid? GetSessionIdFromToken(string token)
    {
        var principal = ValidateToken(token);
        var sessionClaim = principal?.FindFirst("session_id")?.Value;
        return Guid.TryParse(sessionClaim, out var sessionId) ? sessionId : null;
    }

    public Guid? GetUserIdFromToken(string token)
    {
        var principal = ValidateToken(token);
        var userClaim = principal?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userClaim, out var userId) ? userId : null;
    }

    private ClaimsPrincipal? ValidateToken(string token)
    {
        var handler = new JwtSecurityTokenHandler();
        try
        {
            return handler.ValidateToken(token, GetValidationParameters(), out _);
        }
        catch
        {
            return null;
        }
    }

    private string WriteToken(IEnumerable<Claim> claims, double? expiryMinutes = null)
    {
        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(_config["Jwt:Key"]!)
        );

        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _config["Jwt:Issuer"],
            audience: _config["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(
                expiryMinutes ?? Convert.ToDouble(_config["Jwt:ExpiryInMinutes"])
            ),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private TokenValidationParameters GetValidationParameters()
    {
        return new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = _config["Jwt:Issuer"],
            ValidAudience = _config["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(_config["Jwt:Key"]!)
            )
        };
    }
}
