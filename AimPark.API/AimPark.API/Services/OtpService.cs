using System.Security.Cryptography;
using System.Text;
using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    public class OtpService : IOtpService
    {
        private readonly IConfiguration _configuration;

        public OtpService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public TimeSpan OtpExpiry => TimeSpan.FromMinutes(10);
        public int MaxAttempts => 3;

        public string GenerateOtp()
        {
            return RandomNumberGenerator.GetInt32(100000, 999999).ToString();
        }

        public string HashOtp(string otp)
        {
            var pepper = _configuration["Otp:Pepper"] ?? "dev-otp-pepper";
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(otp + pepper));
            return Convert.ToHexString(bytes);
        }

        public bool VerifyOtp(string otp, string hash)
        {
            return HashOtp(otp).Equals(hash, StringComparison.OrdinalIgnoreCase);
        }
    }
}
