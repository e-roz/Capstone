namespace AimPark.API.Helpers
{
    public static class IdentifierNormalizer
    {
        public static string NormalizeEmail(string email)
            => email.Trim().ToLowerInvariant();

        public static string? NormalizePhone(string? phone)
        {
            if (string.IsNullOrWhiteSpace(phone))
                return null;

            var trimmed = phone.Trim();
            return trimmed.StartsWith('+') ? trimmed : $"+{trimmed.TrimStart('+')}";
        }
    }
}
