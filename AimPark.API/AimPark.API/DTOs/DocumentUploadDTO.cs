namespace AimPark.API.DTOs
{
    public class DocumentUploadDTO
    {
        public IFormFile License { get; set; } = null!;

        public IFormFile OR { get; set; } = null!;

        public IFormFile CR { get; set; } = null!;


    }
}
