namespace AimPark.API.DTOs
{
    public class CreateGateDeviceDto
    {
        public string Name { get; set; } = string.Empty;
        public int Gate { get; set; }
    }

    /// <summary>
    /// Returned once, at creation. <see cref="ApiKey"/> is the only time the
    /// plaintext key exists outside the device — it is hashed before storage
    /// and cannot be recovered afterwards. Losing it means issuing a new one.
    /// </summary>
    public class CreatedGateDeviceResponse
    {
        public Guid DeviceId { get; set; }
        public string Name { get; set; } = string.Empty;
        public int Gate { get; set; }
        public string ApiKey { get; set; } = string.Empty;
        public string Warning { get; set; } =
            "Copy this key now — it is not stored and cannot be shown again.";
    }

    public class GateDeviceResponse
    {
        public Guid DeviceId { get; set; }
        public string Name { get; set; } = string.Empty;
        public int Gate { get; set; }

        /// <summary>Leading characters of the key, for telling devices apart.</summary>
        public string ApiKeyPrefix { get; set; } = string.Empty;

        public bool IsRevoked { get; set; }
        public DateTime? LastSeenAt { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
