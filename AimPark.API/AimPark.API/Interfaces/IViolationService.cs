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
        Task<ActionResult<ViolationListResponse>> ListAllAsync(
            string? status, string? search, Guid? userId, Guid? ruleId,
            int page, int pageSize, CancellationToken ct);
        Task<ActionResult<ViolationDetailResponse>> GetDetailForAdminAsync(Guid violationId, CancellationToken ct);

        /// <summary>
        /// Clears a violation that should never have been issued. Only while
        /// Issued or PendingAppeal; a reason is required.
        /// </summary>
        Task<ActionResult<object>> DismissAsync(Guid violationId, Guid adminUserId, ViolationReasonDto dto, CancellationToken ct);

        /// <summary>
        /// Makes the user accountable now instead of waiting out the appeal
        /// deadline. Only while Issued; a reason is required.
        /// </summary>
        Task<ActionResult<object>> MakeAccountableAsync(Guid violationId, Guid adminUserId, ViolationReasonDto dto, CancellationToken ct);

        /// <summary>
        /// Every Issued violation whose appeal deadline has passed becomes
        /// Accountable. Run by the clock. Returns how many changed.
        /// </summary>
        Task<int> PromoteLapsedAsync(DateTime now, CancellationToken ct);

        // Appeals
        Task<ActionResult<object>> SubmitAppealAsync(Guid userId, Guid violationId, SubmitAppealDto dto, CancellationToken ct);
        Task<ActionResult<ViolationAppealListResponse>> ListAppealsAsync(string? status, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<object>> DecideAppealAsync(Guid appealId, Guid adminUserId, DecideAppealDto dto, CancellationToken ct);
    }
}
