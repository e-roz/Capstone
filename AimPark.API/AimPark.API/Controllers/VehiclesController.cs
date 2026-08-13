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

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
