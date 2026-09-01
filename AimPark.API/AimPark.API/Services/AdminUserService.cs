using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class AdminUserService : IAdminUserService
    {
        private readonly IRepository<User> _users;
        private readonly IRepository<AdminAuditLog> _auditLogs;
        private readonly AppDbContext _db;
        private readonly IFileStorageService _storage;

        public AdminUserService(
            IRepository<User> users,
            IRepository<AdminAuditLog> auditLogs,
            AppDbContext db,
            IFileStorageService storage)
        {
            _users = users;
            _auditLogs = auditLogs;
            _db = db;
            _storage = storage;
        }

        // GET /api/admin/users?page=1&pageSize=20&status=Suspended&search=cruz&role=User (includes archived users)
        public async Task<ActionResult<UserListResponse>> ListAsync(int page, int pageSize, string? status, string? search, string? role, CancellationToken ct)
        {
            // Clamp to sane defaults
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<User>().AsNoTracking();

            // "Archived" isn't a real AccountStatus — it's the separate IsDeleted flag —
            // so it's handled as a virtual filter value here rather than a real enum member.
            if (string.Equals(status, "Archived", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(u => u.IsDeleted);
            }
            else if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<AccountStatus>(status, true, out var parsedStatus))
            {
                query = query.Where(u => u.AccountStatus == parsedStatus);
            }

            if (!string.IsNullOrWhiteSpace(role) && Enum.TryParse<UserRole>(role, true, out var parsedRole))
            {
                query = query.Where(u => u.Role == parsedRole);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim().ToLower();
                query = query.Where(u =>
                    u.FullName.ToLower().Contains(term) ||
                    u.Email.ToLower().Contains(term) ||
                    _db.Set<Vehicle>().Any(v => v.UserId == u.Id && v.PlateNumber.ToLower().Contains(term)));
            }

            var totalCount = await query.CountAsync(ct);

            var users = await query
                .OrderByDescending(u => u.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(u => new UserSummaryResponse
                {
                    UserId       = u.Id,
                    FullName     = u.FullName,
                    Email        = u.Email,
                    Role         = u.Role.ToString(),
                    AccountStatus = u.AccountStatus.ToString(),
                    RfidStatus   = u.RfidStatus.ToString(),
                    IsDeleted    = u.IsDeleted,
                    CreatedAt    = u.CreatedAt
                })
                .ToListAsync(ct);

            return new OkObjectResult(new UserListResponse
            {
                Users      = users,
                TotalCount = totalCount,
                Page       = page,
                PageSize   = pageSize
            });
        }

        // POST /api/admin/users/{userId}/suspend
        public async Task<ActionResult<object>> SuspendAsync(Guid userId, Guid adminUserId, SuspendUserDto dto, CancellationToken ct)
        {
            if (userId == adminUserId)
                return new BadRequestObjectResult(new { message = "You cannot suspend your own account." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.IsDeleted)
                return new BadRequestObjectResult(new { message = "Cannot suspend an archived user." });

            if (user.AccountStatus == AccountStatus.Suspended)
                return new BadRequestObjectResult(new { message = "User is already suspended." });

            var oldStatus = user.AccountStatus.ToString();
            user.AccountStatus = AccountStatus.Suspended;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Suspend", oldStatus, user.AccountStatus.ToString(), dto.Reason, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "User suspended." });
        }

        // POST /api/admin/users/{userId}/unsuspend
        public async Task<ActionResult<object>> UnsuspendAsync(Guid userId, Guid adminUserId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.IsDeleted)
                return new BadRequestObjectResult(new { message = "Cannot unsuspend an archived user." });

            if (user.AccountStatus != AccountStatus.Suspended)
                return new BadRequestObjectResult(new { message = "User is not currently suspended." });

            var oldStatus = user.AccountStatus.ToString();
            // Revert to Active — suspension is always lifted back to Active,
            // since the user was Active before being suspended.
            user.AccountStatus = AccountStatus.Active;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Unsuspend", oldStatus, user.AccountStatus.ToString(), null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "User unsuspended. Account restored to Active." });
        }

        // DELETE /api/admin/users/{userId} (archive — soft delete)
        public async Task<ActionResult<object>> ArchiveAsync(Guid userId, Guid adminUserId, ArchiveUserDto dto, CancellationToken ct)
        {
            if (userId == adminUserId)
                return new BadRequestObjectResult(new { message = "You cannot archive your own account." });

            var admin = await _users.FindAsync(u => u.Id == adminUserId, ct);
            if (admin?.PasswordHash is null)
                return new BadRequestObjectResult(new { message = "Password confirmation is unavailable for this admin account." });

            if (string.IsNullOrEmpty(dto.Password) || !BCrypt.Net.BCrypt.Verify(dto.Password, admin.PasswordHash))
                return new UnauthorizedObjectResult(new { message = "Incorrect password." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.IsDeleted)
                return new BadRequestObjectResult(new { message = "User is already archived." });

            var oldValue = $"IsDeleted=false";
            user.IsDeleted = true;
            user.DeletedAt = DateTime.UtcNow;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Archive", oldValue, "IsDeleted=true", null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "User archived. Data is retained and can be restored later." });
        }

        // POST /api/admin/users/{userId}/restore
        public async Task<ActionResult<object>> RestoreAsync(Guid userId, Guid adminUserId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (!user.IsDeleted)
                return new BadRequestObjectResult(new { message = "User is not archived." });

            var wasSuspended = user.AccountStatus == AccountStatus.Suspended;
            var oldValue = $"IsDeleted=true, DeletedAt={user.DeletedAt:O}, AccountStatus={user.AccountStatus}";
            user.IsDeleted = false;
            user.DeletedAt = null;

            // Restore is meant to fully undo whatever locked the account out, so a suspension
            // picked up before/along with the deletion is lifted too — otherwise the account
            // comes back "restored" but still unable to log in, which reads as a bug to admins.
            // Registration-review statuses (Rejected/PendingReview) are left untouched since
            // restore isn't an approval action.
            if (wasSuspended)
                user.AccountStatus = AccountStatus.Active;

            user.UpdatedAt = DateTime.UtcNow;

            var newValue = $"IsDeleted=false, AccountStatus={user.AccountStatus}";
            await LogActionAsync(adminUserId, userId, "Restore", oldValue, newValue, null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            var message = wasSuspended
                ? "User restored successfully. Suspension was also lifted."
                : "User restored successfully.";
            return new OkObjectResult(new { message });
        }

        // POST /api/admin/users/{userId}/assign-rfid
        public async Task<ActionResult<object>> AssignRfidAsync(Guid userId, Guid adminUserId, AssignRfidDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.RfidTagId))
                return new BadRequestObjectResult(new { message = "RFID tag ID is required." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            // Squeezed into one spelling before it is stored, so a card read by
            // the desk reader and the same card typed off its label end up as
            // the same string. Lookups at the gate are exact comparisons, so
            // this is what stops "registered but never recognised".
            var tagId = RfidTag.Normalize(dto.RfidTagId);
            if (tagId.Length == 0)
                return new BadRequestObjectResult(new { message = "RFID tag ID is required." });

            var tagInUse = await _users.ExistsAsync(u => u.Id != userId && u.RfidTagId == tagId, ct);
            if (tagInUse)
                return new BadRequestObjectResult(new { message = "This RFID tag is already assigned to another user." });

            // A card revoked as lost/stolen/damaged stays blocked forever — see
            // RfidCardState. Everything else (graduated, no longer needed) left
            // a Free row behind, which a straight reassignment now clears.
            var card = await _db.Set<RfidCard>().FindAsync([tagId], ct);
            if (card is not null && card.State == RfidCardState.Blocked)
                return new BadRequestObjectResult(new
                {
                    message = $"This card was reported {card.Reason.ToString().ToLowerInvariant()} and cannot be reissued."
                });

            var oldValue = $"RfidTagId={user.RfidTagId}, RfidStatus={user.RfidStatus}";
            user.RfidTagId = tagId;
            user.RfidStatus = RfidStatus.Active;
            user.UpdatedAt = DateTime.UtcNow;

            if (card is not null) _db.Set<RfidCard>().Remove(card);

            await LogActionAsync(adminUserId, userId, "AssignRfid", oldValue, $"RfidTagId={user.RfidTagId}, RfidStatus={user.RfidStatus}", null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "RFID tag assigned." });
        }

        // POST /api/admin/users/{userId}/revoke-rfid
        public async Task<ActionResult<object>> RevokeRfidAsync(Guid userId, Guid adminUserId, RevokeRfidDto dto, CancellationToken ct)
        {
            if (!Enum.TryParse<RfidRevokeReason>(dto.Reason, true, out var reason))
                return new BadRequestObjectResult(new { message = "Choose a reason for the revoke." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var (ok, message) = await RevokeCardAsync(user, adminUserId, reason, dto.Note, ct);
            if (!ok)
                return new BadRequestObjectResult(new { message });

            await _users.SaveAsync(ct);
            return new OkObjectResult(new { message });
        }

        // POST /api/admin/users/bulk-revoke-rfid
        //
        // Built for the end-of-year graduation sweep: dozens of cards coming
        // back at once, all for the same reason. One bad ID in the batch
        // (already-unassigned, already-archived) is skipped and reported, not
        // a reason to fail the other 40.
        public async Task<ActionResult<BulkRevokeRfidResponse>> BulkRevokeRfidAsync(Guid adminUserId, BulkRevokeRfidDto dto, CancellationToken ct)
        {
            if (dto.UserIds.Count == 0)
                return new BadRequestObjectResult(new { message = "Select at least one user." });

            if (!Enum.TryParse<RfidRevokeReason>(dto.Reason, true, out var reason))
                return new BadRequestObjectResult(new { message = "Choose a reason for the revoke." });

            var response = new BulkRevokeRfidResponse();

            foreach (var userId in dto.UserIds)
            {
                var user = await _users.FindAsync(u => u.Id == userId, ct);
                if (user is null)
                {
                    response.Skipped.Add(new BulkRevokeSkip { UserId = userId, Reason = "User not found." });
                    continue;
                }

                var (ok, message) = await RevokeCardAsync(user, adminUserId, reason, dto.Note, ct);
                if (!ok)
                {
                    response.Skipped.Add(new BulkRevokeSkip { UserId = userId, Reason = message });
                    continue;
                }

                response.Revoked++;
            }

            await _users.SaveAsync(ct);
            return new OkObjectResult(response);
        }

        // GET /api/admin/rfid-cards?state=Free
        //
        // The pool an admin picks from when handing out a card someone else
        // already carried — and, filtered to Blocked, the list of UIDs that
        // must never be reissued.
        public async Task<ActionResult<List<RfidCardResponse>>> ListRfidCardsAsync(string? state, CancellationToken ct)
        {
            var query = _db.Set<RfidCard>().AsNoTracking().AsQueryable();

            if (!string.IsNullOrWhiteSpace(state) && Enum.TryParse<RfidCardState>(state, true, out var parsedState))
                query = query.Where(c => c.State == parsedState);

            var cards = await query
                .OrderByDescending(c => c.UpdatedAt)
                .Select(c => new RfidCardResponse
                {
                    RfidTagId = c.RfidTagId,
                    State = c.State.ToString(),
                    Reason = c.Reason.ToString(),
                    Note = c.Note,
                    LastUserId = c.LastUserId,
                    LastUserName = c.LastUserName,
                    UpdatedAt = c.UpdatedAt
                })
                .ToListAsync(ct);

            return new OkObjectResult(cards);
        }

        /// <summary>
        /// The half of a revoke shared by the single and bulk endpoints: clear
        /// the user's side, then file the card as Free or Blocked depending on
        /// why it came back. Caller still owns <c>SaveAsync</c> — this only
        /// stages changes, so a bulk run costs one round trip, not N.
        /// </summary>
        private async Task<(bool ok, string message)> RevokeCardAsync(
            User user, Guid adminUserId, RfidRevokeReason reason, string? note, CancellationToken ct)
        {
            if (user.RfidStatus == RfidStatus.Unassigned)
                return (false, $"{user.FullName} has no RFID tag assigned.");

            var tagId = user.RfidTagId!;
            var oldValue = $"RfidTagId={user.RfidTagId}, RfidStatus={user.RfidStatus}";

            user.RfidTagId = null;
            user.RfidStatus = RfidStatus.Unassigned;
            user.UpdatedAt = DateTime.UtcNow;
            _users.Update(user);

            var state = reason is RfidRevokeReason.Lost or RfidRevokeReason.Stolen or RfidRevokeReason.Damaged
                ? RfidCardState.Blocked
                : RfidCardState.Free;

            var card = await _db.Set<RfidCard>().FindAsync([tagId], ct);
            if (card is null)
            {
                card = new RfidCard { RfidTagId = tagId };
                _db.Set<RfidCard>().Add(card);
            }

            card.State = state;
            card.Reason = reason;
            card.Note = note;
            card.LastUserId = user.Id;
            card.LastUserName = user.FullName;
            card.UpdatedAt = DateTime.UtcNow;

            var reasonNote = note is null ? reason.ToString() : $"{reason}: {note}";
            await LogActionAsync(adminUserId, user.Id, "RevokeRfid", oldValue, "RfidTagId=null, RfidStatus=Unassigned", reasonNote, ct);

            return (true, "RFID tag revoked.");
        }

        // DELETE /api/admin/users/{userId}/documents
        //
        // Archiving keeps everything, which is right for the records and wrong
        // for the photographs: an RAF, a licence and an OR carry a home address,
        // a licence number and a signature, and the reason to hold them ends
        // when the review that needed them is over. This removes those images
        // and the raw readings taken off them, and touches nothing else — the
        // account, its violations, its payments and its parking history all
        // stay, because those are the school’s records and not only the
        // user’s.
        public async Task<ActionResult<object>> DeleteDocumentsAsync(
            Guid userId,
            Guid adminUserId,
            DeleteDocumentsDto dto,
            CancellationToken ct)
        {
            var admin = await _users.FindAsync(u => u.Id == adminUserId, ct);
            if (admin?.PasswordHash is null)
                return new BadRequestObjectResult(new { message = "Password confirmation is unavailable for this admin account." });

            if (string.IsNullOrEmpty(dto.Password) || !BCrypt.Net.BCrypt.Verify(dto.Password, admin.PasswordHash))
                return new UnauthorizedObjectResult(new { message = "Incorrect password." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            // A decision nobody has made yet is the one case where these images
            // are still needed: the reviewer is about to look at them, and an
            // applicant cannot be judged on documents nobody can see.
            if (user.AccountStatus == AccountStatus.PendingReview)
            {
                return new BadRequestObjectResult(new
                {
                    message = "This user is still waiting for review. Approve or reject them first — "
                            + "the documents are the evidence that decision is made on."
                });
            }

            var documents = await _db.Set<Document>()
                .Where(d => d.UserId == userId)
                .ToListAsync(ct);

            if (documents.Count == 0)
                return new BadRequestObjectResult(new { message = "This user has no stored documents." });

            // Files first, rows second. The row is the only record of where the
            // file is, so dropping it before the delete succeeds would leave the
            // image in the bucket with nothing left pointing at it — the one
            // outcome this action exists to prevent.
            await _storage.DeleteAsync(
                "documents",
                documents
                    .Select(d => d.FilePath)
                    .Where(path => !string.IsNullOrWhiteSpace(path))
                    .ToList(),
                ct);

            _db.Set<Document>().RemoveRange(documents);

            // The verdicts stay — they say who was approved and on what
            // grounds — but the raw OCR text is a transcript of the documents
            // themselves, so it goes with them.
            var verifications = await _db.Set<DocumentVerification>()
                .Where(v => v.UserId == userId && v.RawPayloads != null)
                .ToListAsync(ct);

            foreach (var verification in verifications)
            {
                verification.RawPayloads = null;
            }

            await LogActionAsync(
                adminUserId,
                userId,
                "DeleteDocuments",
                $"Documents={documents.Count}",
                "Documents=0",
                dto.Reason,
                ct);

            await _db.SaveChangesAsync(ct);

            var noun = documents.Count == 1 ? "document image" : "document images";
            return new OkObjectResult(new
            {
                message = $"{documents.Count} {noun} deleted. The account and its records are unchanged."
            });
        }

        private async Task LogActionAsync(
            Guid adminUserId,
            Guid targetUserId,
            string action,
            string? oldValue,
            string? newValue,
            string? reason,
            CancellationToken ct)
        {
            await _auditLogs.AddAsync(new AdminAuditLog
            {
                Id = Guid.NewGuid(),
                AdminUserId = adminUserId,
                TargetUserId = targetUserId,
                Action = action,
                OldValue = oldValue,
                NewValue = newValue,
                Reason = reason,
                CreatedAt = DateTime.UtcNow
            }, ct);

            // The same event, recorded from the other direction. The audit log
            // answers "what did this administrator do"; the activity log answers
            // "what happened to this account". An auditor asks both, and every
            // action that reaches this method is one a user would want to see on
            // their own history.
            //
            // Added to the context rather than saved here: the caller's own
            // SaveAsync flushes it, so the status change and its log line land in
            // one transaction instead of two.
            var activity = action switch
            {
                "AssignRfid" => UserActivities.RfidAssigned,
                "RevokeRfid" => UserActivities.RfidRevoked,
                _ => UserActivities.StatusChanged
            };

            var email = await _db.Users
                .Where(u => u.Id == targetUserId)
                .Select(u => u.Email)
                .FirstOrDefaultAsync(ct) ?? string.Empty;

            _db.UserActivityLogs.Add(new UserActivityLog
            {
                UserId = targetUserId,
                EmailAtTime = email,
                Activity = activity,
                // No IP: this was an administrator acting on someone else's
                // account, and *which* administrator is already on the audit row.
                Detail = DescribeAction(action, oldValue, newValue, reason)
            });
        }

        /// <summary>
        /// A plain-English description of an admin action, for the user activity
        /// log.
        ///
        /// The audit table stores machine state — <c>IsDeleted=true</c>,
        /// <c>RfidTagId=ABC123, RfidStatus=Active</c> — which is correct for a
        /// record and unreadable in a table someone has to scan. This table is
        /// read by people, so it stores the sentence.
        /// </summary>
        private static string DescribeAction(
            string action,
            string? oldValue,
            string? newValue,
            string? reason)
        {
            var summary = action switch
            {
                "Archive" => "Account archived",
                "Restore" => "Account restored",
                "DeleteDocuments" => "ID documents deleted",
                "AssignRfid" => DescribeCard(oldValue, newValue),
                "RevokeRfid" => ReadField(oldValue, "RfidTagId") is { Length: > 0 } tag
                    ? $"RFID card {tag} revoked"
                    : "RFID card revoked",
                "Suspend" => "Account suspended",
                "Unsuspend" => "Account reinstated",
                "Approve" => "Registration approved",
                "Reject" => "Registration rejected",
                _ => oldValue is not null && newValue is not null
                    ? $"{oldValue} -> {newValue}"
                    : action
            };

            return string.IsNullOrWhiteSpace(reason) ? summary : $"{summary} ({reason})";
        }

        private static string DescribeCard(string? oldValue, string? newValue)
        {
            var before = ReadField(oldValue, "RfidTagId");
            var after = ReadField(newValue, "RfidTagId");

            if (string.IsNullOrEmpty(after)) return "RFID card assigned";

            return string.IsNullOrEmpty(before)
                ? $"RFID card {after} assigned"
                : $"RFID card {before} replaced with {after}";
        }

        /// <summary>
        /// Pulls one value out of a <c>Key=Value, Key=Value</c> string. Returns
        /// null for anything not in that shape, which is most actions.
        /// </summary>
        private static string? ReadField(string? raw, string key)
        {
            if (string.IsNullOrEmpty(raw)) return null;

            foreach (var part in raw.Split(','))
            {
                var split = part.IndexOf('=');
                if (split <= 0) continue;

                if (part[..split].Trim().Equals(key, StringComparison.OrdinalIgnoreCase))
                    return part[(split + 1)..].Trim();
            }

            return null;
        }
    }
}
