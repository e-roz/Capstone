namespace AimPark.API.Entities
{
    /// <summary>
    /// One tap at a USB gate reader, or one manual open, as the guard's live
    /// log shows it. Written on the site server and sent up through the
    /// outbox, so the online admin panel's Gate taps tab sees it too. The
    /// photo itself stays on the guard PC.
    /// </summary>
    /// <remarks>
    /// A copy, not a link: the name and plates are written as they were at the
    /// moment of the tap, so the log still reads true after a driver changes
    /// vehicle or a visitor pass is returned. The movement itself, when the
    /// gate opened, is in <see cref="ParkingLog"/>.
    /// </remarks>
    public class GateTapEvent
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public DateTime At { get; set; } = DateTime.UtcNow;

        public int Gate { get; set; }

        public string? ReaderName { get; set; }

        /// <summary>IN, OUT, or "-" when the tap never got as far as a direction.</summary>
        public string Direction { get; set; } = "-";

        public bool Opened { get; set; }

        public string Message { get; set; } = string.Empty;

        /// <summary>Null for a manual open.</summary>
        public string? RfidTagId { get; set; }

        /// <summary>The driver's or visitor's name, or null for a card nobody holds.</summary>
        public string? PersonName { get; set; }

        /// <summary>Driver, Visitor, Unknown, or Manual.</summary>
        public string PersonKind { get; set; } = GateTapPersonKind.Unknown;

        public Guid? UserId { get; set; }

        public Guid? VisitorPassId { get; set; }

        /// <summary>What the camera at this gate read around the tap, if anything.</summary>
        public string? CameraPlate { get; set; }

        /// <summary>The plates on file for the card's holder, comma separated.</summary>
        public string? RegisteredPlates { get; set; }

        /// <summary>Null when there was no camera plate or no plate on file to compare.</summary>
        public bool? PlateMatches { get; set; }

        public Guid? ParkingLogId { get; set; }

        /// <summary>A camera frame was saved for this tap.</summary>
        public bool HasPhoto { get; set; }
    }

    public static class GateTapPersonKind
    {
        public const string Driver = "Driver";
        public const string Visitor = "Visitor";
        public const string Unknown = "Unknown";
        public const string Manual = "Manual";
    }
}
