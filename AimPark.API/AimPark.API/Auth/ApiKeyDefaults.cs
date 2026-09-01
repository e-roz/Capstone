namespace AimPark.API.Auth
{
    public static class ApiKeyDefaults
    {
        /// <summary>Authentication scheme name for gate hardware.</summary>
        public const string AuthenticationScheme = "ApiKey";

        /// <summary>Request header carrying the device key.</summary>
        public const string HeaderName = "X-Api-Key";

        /// <summary>
        /// Role granted to an authenticated device. Deliberately separate from
        /// Admin and Security so a compromised reader cannot reach anything a
        /// staff account can.
        /// </summary>
        public const string DeviceRole = "Device";

        /// <summary>Claim holding the gate number the device is mounted at.</summary>
        public const string GateClaim = "gate";

        /// <summary>
        /// Gate number for a reader that is not on a barrier at all — the one
        /// on the admin's desk, used to read a card during registration.
        ///
        /// It shares the device-key machinery because the need is identical: a
        /// reader with no operator to log it in. What differs is reach, and
        /// that is enforced by this number — an enrollment reader is refused at
        /// the entry and exit endpoints, so a key lifted off the desk unit
        /// cannot open a barrier.
        /// </summary>
        public const int EnrollmentGate = 0;

        /// <summary>Prefix on every issued key, so one is recognisable on sight.</summary>
        public const string KeyPrefix = "aimpark_";
    }
}
