using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IViolationService
    {
        // Policy rules
        Task<ActionResult<List<PolicyRuleResponse>>> ListPolicyRulesAsync(CancellationToken ct);
        Task<ActionResult<object>> CreatePolicyRuleAsync(UpsertPolicyRuleDto dto, CancellationToken ct);
        Task<ActionResult<object>> UpdatePolicyRuleAsync(Guid ruleId, UpsertPolicyRuleDto dto, CancellationToken ct);

        // Violations
        Task<ActionResult<object>> IssueAsync(IssueViolationDto dto, Guid adminUserId, CancellationToken ct);
        Task<ActionResult<ViolationListResponse>> GetMyViolationsAsync(Guid userId, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<ViolationDetailResponse>> GetMyViolationDetailAsync(Guid userId, Guid violationId, CancellationToken ct);
        Task<ActionResult<ViolationListResponse>> ListAllAsync(string? status, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<ViolationDetailResponse>> GetDetailForAdminAsync(Guid violationId, CancellationToken ct);
        Task<ActionResult<object>> DismissAsync(Guid violationId, Guid adminUserId, CancellationToken ct);

        // Appeals
        Task<ActionResult<object>> SubmitAppealAsync(Guid userId, Guid violationId, SubmitAppealDto dto, CancellationToken ct);
        Task<ActionResult<ViolationAppealListResponse>> ListAppealsAsync(string? status, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<object>> DecideAppealAsync(Guid appealId, Guid adminUserId, DecideAppealDto dto, CancellationToken ct);
    }
}
