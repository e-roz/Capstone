namespace AimPark.API.Entities
{
    /// <summary>
    /// A file attached to a violation appeal — a photo of the parked vehicle, a
    /// receipt, a permit. Reason text alone often cannot settle a dispute, so an
    /// appeal without evidence is hard for either side to argue.
    /// </summary>
    public class AppealEvidence
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        //Foreign key to ViolationAppeal
        public Guid AppealId { get; set; }
        public ViolationAppeal Appeal { get; set; } = null!;

        public string StoragePath { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;

        public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
    }
}
