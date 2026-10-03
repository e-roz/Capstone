using System.Security.Claims;
using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using AimPark.API.Sync.Site.GateReaders;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// Idle visitor cards tapped at a gate, and the guard's answer: who is in
    /// the car. Saving lends the card, logs the entry and opens that barrier.
    /// </summary>
    /// <remarks>
    /// Site server only — the taps are held in memory on the guard post's PC
    /// (see <see cref="PendingVisitorRegistrations"/>). The security screen
    /// polls the list and pops the form; the first guard to save wins.
    /// </remarks>
    [ApiController]
    [Route("api/site/visitor-registrations")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin,Security")]
    public class VisitorRegistrationsController : ControllerBase
    {
        private readonly PendingVisitorRegistrations? _pending;
        private readonly UsbGateReaders? _readers;
        private readonly EspNowHubs? _hubs;
        private readonly IVisitorPassService _passes;
        private readonly IParkingHistoryService _parking;
        private readonly AppDbContext _db;

        public VisitorRegistrationsController(
            IServiceProvider services, IVisitorPassService passes, IParkingHistoryService parking, AppDbContext db)
        {
            _pending = services.GetService<PendingVisitorRegistrations>();
            _readers = services.GetService<UsbGateReaders>();
            _hubs = services.GetService<EspNowHubs>();
            _passes = passes;
            _parking = parking;
            _db = db;
        }

        public class PendingVisitorRegistrationResponse
        {
            public Guid Id { get; set; }
            public string RfidTagId { get; set; } = string.Empty;
            public string CardLabel { get; set; } = string.Empty;
            public int Gate { get; set; }
            public DateTime TappedAt { get; set; }

            /// <summary>What the gate camera read around the tap, to prefill the plate. Null if nothing.</summary>
            public string? CameraPlate { get; set; }
        }

        /// <summary>The same details the desk form asks for. The card comes from the tap.</summary>
        public class CompleteVisitorRegistrationDto
        {
            public string VisitorName { get; set; } = string.Empty;
            public string PlateNumber { get; set; } = string.Empty;
            public string VehicleType { get; set; } = "Car";
            public string? Purpose { get; set; }
        }

        [HttpGet]
        public async Task<ActionResult<List<PendingVisitorRegistrationResponse>>> List(CancellationToken ct)
        {
            if (_pending is null) return NotAtGuardPost();

            var list = new List<PendingVisitorRegistrationResponse>();
            foreach (var p in _pending.List())
            {
                var from = p.TappedAt - ParkingHistoryService.AlprMatchWindow;
                var cameraPlate = await _db.Set<AlprReading>().AsNoTracking()
                    .Where(r => r.Gate == p.Gate && r.ReadAt >= from)
                    .OrderByDescending(r => r.ReadAt)
                    .Select(r => r.PlateNumber)
                    .FirstOrDefaultAsync(ct);

                list.Add(new PendingVisitorRegistrationResponse
                {
                    Id = p.Id,
                    RfidTagId = p.RfidTagId,
                    CardLabel = p.CardLabel,
                    Gate = p.Gate,
                    TappedAt = p.TappedAt,
                    CameraPlate = cameraPlate
                });
            }

            return Ok(list);
        }

        [HttpPost("{id:guid}")]
        public async Task<ActionResult<object>> Complete(
            Guid id, [FromBody] CompleteVisitorRegistrationDto dto, CancellationToken ct)
        {
            if (_pending is null) return NotAtGuardPost();

            var pending = _pending.Take(id);
            if (pending is null)
                return Conflict(new
                {
                    message = "Another guard already handled this card, or it timed out. Ask the visitor to tap again."
                });

            var guardId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

            var issued = await _passes.IssueAsync(new IssueVisitorPassDto
            {
                RfidTagId = pending.RfidTagId,
                VisitorName = dto.VisitorName,
                PlateNumber = dto.PlateNumber,
                VehicleType = dto.VehicleType,
                Purpose = dto.Purpose
            }, guardId, ct);

            if (Refused(issued.Result) is { } issueError)
            {
                // Most likely a typo in the form. Keep the tap so the guard can fix it.
                _pending.Restore(pending);
                return issueError;
            }

            var entry = await _parking.LogEntryAsync(
                new LogParkingEntryDto { RfidTagId = pending.RfidTagId, Gate = pending.Gate },
                loggedByUserId: guardId, loggedByDeviceId: null, ct);

            if (Refused(entry.Result) is { } entryError)
            {
                // No bay for them, usually. The car is turned away, so the pass
                // ends here and the card is still in the guard's hand.
                if (issued.Result is ObjectResult { Value: VisitorPassResponse pass })
                    await _passes.ReturnAsync(pass.PassId, guardId, ct);
                return entryError;
            }

            var problem = OpenBarrier(pending);
            var message = $"Visitor card {pending.CardLabel} lent to {dto.VisitorName.Trim()}.";

            _readers?.RecordVisitorEntry(pending, new GateTapOutcome(
                problem is null, "IN", problem is null ? $"{message} Gate opened." : $"{message} {problem}"));

            return Ok(new
            {
                message = problem is null ? $"{message} Gate {pending.Gate} opened." : $"{message} Entry logged, but {problem}",
                gateOpened = problem is null
            });
        }

        /// <summary>The car was turned away. The barrier stays shut and the card stays unlent.</summary>
        [HttpDelete("{id:guid}")]
        public ActionResult<object> Dismiss(Guid id)
        {
            if (_pending is null) return NotAtGuardPost();

            return _pending.Take(id) is null
                ? NotFound(new { message = "That tap was already handled." })
                : Ok(new { message = "Visitor turned away." });
        }

        /// <summary>Null when the barrier was told to open; otherwise what the guard should do.</summary>
        private string? OpenBarrier(PendingVisitorRegistration pending)
        {
            var by = User.FindFirst(ClaimTypes.Email)?.Value ?? "a guard";

            if (pending.Node is not null)
                return _hubs?.OpenManually(pending.Port, pending.Node, by, logAsManual: false) is { } problem
                    ? problem.TrimEnd('.') + ". Open the barrier by hand."
                    : _hubs is null ? "the gate couldn't be reached. Open the barrier by hand." : null;

            return _readers?.OpenManually(pending.Port, by, logAsManual: false) == true
                ? null
                : $"the reader on {pending.Port} isn't connected. Open the barrier by hand.";
        }

        private static ObjectResult? Refused(ActionResult? result) =>
            result is ObjectResult { StatusCode: >= 300 } refused ? refused : null;

        private ObjectResult NotAtGuardPost() => BadRequest(new
        {
            message = "Visitor cards are registered at the guard post. Open this screen from the guard post's panel."
        });
    }
}
