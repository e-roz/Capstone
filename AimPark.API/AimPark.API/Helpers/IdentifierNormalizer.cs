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

        /// <summary>
        /// Uppercase, with spaces and dashes stripped.
        /// </summary>
        /// <remarks>
        /// Every plate is stored this way. A gate camera reads "ABC1234" while a user
        /// types "ABC 1234", and without one canonical form the lookup misses and
        /// nothing anywhere reports an error — the driver is simply denied entry with
        /// a valid card. The unique index depends on this too: "ABC 1234" and
        /// "ABC-1234" are two rows for one vehicle otherwise.
        /// </remarks>
        public static string NormalizePlate(string? plate)
        {
            if (string.IsNullOrWhiteSpace(plate))
                return string.Empty;

            return new string(plate
                .Where(char.IsLetterOrDigit)
                .Select(char.ToUpperInvariant)
                .ToArray());
        }
    }
}
