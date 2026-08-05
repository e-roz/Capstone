namespace AimPark.API.DTOs
{
    public class SubmitAppealDto
    {
        public string ReasonText { get; set; } = string.Empty;

        /// <summary>
        /// Supporting photos or documents. Reason text alone often cannot settle
        /// a dispute — a photo of where the vehicle was actually parked usually
        /// can. Sent as multipart, so this endpoint takes [FromForm].
        /// </summary>
        public List<IFormFile>? Evidence { get; set; }
    }
}
