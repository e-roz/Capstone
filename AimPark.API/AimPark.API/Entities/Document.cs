using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class Document
    {
        public Guid Id { get; set; } = Guid.NewGuid();


        public DocumentType Type { get; set; }
        public string FileName { get; set; } = string.Empty;

        //local file path
        public string FilePath { get; set; } = string.Empty;

        public DateTime UploadedAt { get; set; } = DateTime.UtcNow;


        //Foreign key to User
        public Guid UserId { get; set; }
        public User User { get; set; } = null!;
    }
}
