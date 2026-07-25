using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/account")]
    [Authorize]
    public class AccountController : ControllerBase
    {
        private readonly IUserProfileService _userProfileService;

        public AccountController(IUserProfileService userProfileService)
        {
            _userProfileService = userProfileService;
        }

        [HttpGet("profile")]
        public Task<ActionResult<MyProfileResponse>> GetProfile(CancellationToken ct)
            => _userProfileService.GetMyProfileAsync(GetUserId(), ct);

        [HttpPut("profile")]
        public Task<ActionResult<object>> UpdateProfile([FromBody] UpdateProfileDto dto, CancellationToken ct)
            => _userProfileService.UpdateProfileAsync(GetUserId(), dto, ct);

        [HttpPost("change-password")]
        public Task<ActionResult<object>> ChangePassword([FromBody] ChangePasswordDto dto, CancellationToken ct)
            => _userProfileService.ChangePasswordAsync(GetUserId(), dto, ct);

        [HttpGet("access-status")]
        public Task<ActionResult<AccessStatusResponse>> GetAccessStatus(CancellationToken ct)
            => _userProfileService.GetAccessStatusAsync(GetUserId(), ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
