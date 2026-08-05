namespace AimPark.API.Entities
{
    /// <summary>
    /// A piece of gate hardware that talks to the API on its own behalf — an
    /// RFID reader at a barrier, not a person.
    ///
    /// Devices cannot use the normal login flow: there is nobody to type a
    /// password, and JWTs expire after an hour with no refresh path, which
    /// would silently strand a barrier mid-shift. So each unit carries a
    /// long-lived key instead, revocable if the hardware is lost.
    /// </summary>
    public class GateDevice
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        /// <summary>Human label, e.g. "Gate 1 Reader".</summary>
        public string Name { get; set; } = string.Empty;

        /// <summary>
        /// Which barrier this unit is mounted at. A reader is physically fixed
        /// to one gate, so entries it reports are tagged from here rather than
        /// trusted from the request body.
        /// </summary>
        public int Gate { get; set; }

        /// <summary>
        /// SHA-256 of the issued key. The key itself is shown once at creation
        /// and never stored — the same reason a password is never kept in clear.
        /// A fast hash is right here: keys are 256 bits of randomness, so there
        /// is no dictionary to attack and no need for a deliberately slow KDF.
        /// </summary>
        public string ApiKeyHash { get; set; } = string.Empty;

        /// <summary>First characters of the key, so an admin can tell two apart.</summary>
        public string ApiKeyPrefix { get; set; } = string.Empty;

        public bool IsRevoked { get; set; }

        /// <summary>Last time this device successfully authenticated.</summary>
        public DateTime? LastSeenAt { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
