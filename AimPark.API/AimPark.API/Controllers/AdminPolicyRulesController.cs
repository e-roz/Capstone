using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/policy-rules")]
    [Authorize(Roles = "Admin")]
    public class AdminPolicyRulesController : ControllerBase
    {
        private readonly IViolationService _violationService;

        public AdminPolicyRulesController(IViolationService violationService)
        {
            _violationService = violationService;
        }

        [HttpGet]
        public Task<ActionResult<List<PolicyRuleResponse>>> List(CancellationToken ct)
            => _violationService.ListPolicyRulesAsync(ct);

        [HttpPost]
        public Task<ActionResult<object>> Create([FromBody] UpsertPolicyRuleDto dto, CancellationToken ct)
            => _violationService.CreatePolicyRuleAsync(dto, ct);

        [HttpPut("{ruleId:guid}")]
        public Task<ActionResult<object>> Update(Guid ruleId, [FromBody] UpsertPolicyRuleDto dto, CancellationToken ct)
            => _violationService.UpdatePolicyRuleAsync(ruleId, dto, ct);
    }
}
