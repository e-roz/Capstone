using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/vehicles")]
    [Authorize]
    public class VehiclesController : ControllerBase
    {
        private readonly IVehicleService _vehicleService;

        public VehiclesController(IVehicleService vehicleService)
        {
            _vehicleService = vehicleService;
        }

        [HttpGet]
        public Task<ActionResult<List<VehicleDetailResponse>>> GetMyVehicles(CancellationToken ct)
            => _vehicleService.GetMyVehiclesAsync(GetUserId(), ct);

        [HttpPost]
        public Task<ActionResult<object>> AddVehicle([FromBody] VehicleDTO dto, CancellationToken ct)
            => _vehicleService.AddVehicleAsync(dto, GetUserId(), ct);

        /// <summary>
        /// Reads the receipt and plate photo for a vehicle being added.
        /// </summary>
        [HttpPost("documents/scan")]
        [RequestSizeLimit(25 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 25 * 1024 * 1024)]
        public Task<ActionResult<ScanResultResponse>> ScanVehicleDocuments([FromForm] VehicleDocumentUploadDto dto, CancellationToken ct)
            => _vehicleService.ScanVehicleDocumentsAsync(dto, GetUserId(), ct);

        /// <summary>
        /// Commits the vehicle from a scan the user has checked.
        /// </summary>
        [HttpPost("documents/confirm")]
        public Task<ActionResult<object>> ConfirmVehicle([FromBody] ConfirmVehicleDto dto, CancellationToken ct)
            => _vehicleService.ConfirmVehicleAsync(dto, GetUserId(), ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
