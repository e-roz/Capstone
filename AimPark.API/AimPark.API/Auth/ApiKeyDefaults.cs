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

        /// <summary>Prefix on every issued key, so one is recognisable on sight.</summary>
        public const string KeyPrefix = "aimpark_";
    }
}
