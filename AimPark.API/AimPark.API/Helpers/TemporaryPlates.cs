using System.Text.RegularExpressions;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Plates an administrator issues when a vehicle has no real one.
    /// </summary>
    /// <remarks>
    /// Two kinds, both stored without punctuation and shown with a dash:
    ///
    /// <c>EB0001</c> for an e-bike, which the LTO never registers, issued at the
    /// in-person inspection.
    ///
    /// <c>TP0001</c> for a motor vehicle whose Official Receipt carries no plate,
    /// which the LTO can issue. The number is reserved when the applicant submits,
    /// so the vehicle row exists with the type, colour and expiry read from the
    /// receipt, and the administrator confirms it by seeing the vehicle.
    ///
    /// The pattern is strict on purpose: a real car plate can start with "TP"
    /// ("TPA1234"), and only an all-digit suffix is one of these.
    /// </remarks>
    public static partial class TemporaryPlates
    {
        public const string EBikePrefix = "EB";
        public const string VehiclePrefix = "TP";

        [GeneratedRegex(@"^(?:EB|TP)\d{4,}$")]
        private static partial Regex AnyPattern();

        [GeneratedRegex(@"^TP\d{4,}$")]
        private static partial Regex VehiclePattern();

        /// <summary>An issued temporary plate of either kind.</summary>
        public static bool IsTemporary(string? plate)
            => !string.IsNullOrEmpty(plate) && AnyPattern().IsMatch(IdentifierNormalizer.NormalizePlate(plate));

        /// <summary>A temporary plate for a motor vehicle with no plate of its own.</summary>
        public static bool IsVehicleTemporary(string? plate)
            => !string.IsNullOrEmpty(plate) && VehiclePattern().IsMatch(IdentifierNormalizer.NormalizePlate(plate));

        /// <summary>
        /// The next free number after those already issued with
        /// <paramref name="prefix"/>: TP0001, TP0002 and so on.
        /// </summary>
        public static string Next(string prefix, IEnumerable<string> existingPlates)
        {
            var pattern = new Regex($@"^{Regex.Escape(prefix)}(\d{{4,}})$");

            var highest = existingPlates
                .Select(p => pattern.Match(IdentifierNormalizer.NormalizePlate(p)))
                .Where(m => m.Success)
                .Select(m => int.Parse(m.Groups[1].Value))
                .DefaultIfEmpty(0)
                .Max();

            return $"{prefix}{highest + 1:D4}";
        }

        /// <summary>"TP0007" as people read it, "TP-0007". Any other plate is left alone.</summary>
        public static string Format(string plate)
            => IsTemporary(plate)
                ? $"{plate[..2]}-{plate[2..]}"
                : plate;
    }
}
