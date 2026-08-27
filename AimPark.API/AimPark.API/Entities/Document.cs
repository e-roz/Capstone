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

        /// <summary>
        /// SHA-256 of the file as uploaded, lowercase hex.
        /// </summary>
        /// <remarks>
        /// Here so the same photograph submitted by two accounts can be noticed. In a
        /// school the realistic abuse is not forgery but sharing — one person's OR
        /// photo forwarded to a friend — and that is invisible to every other check,
        /// all of which only ever look inside a single submission.
        ///
        /// A hash matches only a byte-identical file, so a re-photograph or a resave
        /// defeats it. That is acceptable: this is meant to catch the effortless
        /// case, and it costs almost nothing to run.
        /// </remarks>
        public string? Sha256 { get; set; }

        public DateTime UploadedAt { get; set; } = DateTime.UtcNow;


        //Foreign key to User
        public Guid UserId { get; set; }
        public User User { get; set; } = null!;
    }
}
