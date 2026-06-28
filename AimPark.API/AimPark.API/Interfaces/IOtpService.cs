using AimPark.API.Enums;

namespace AimPark.API.Interfaces
{
    public interface IOtpService
    {
        string GenerateOtp();
        string HashOtp(string otp);
        bool VerifyOtp(string otp, string hash);
        TimeSpan OtpExpiry { get; }
        int MaxAttempts { get; }
    }
}
