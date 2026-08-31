using System.Security.Claims;
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Auth
{
    /// <summary>
    /// Checks on every request that the account a token names may still use the
    /// app, and answers the ones that may not in words the client can show.
    /// </summary>
    /// <remarks>
    /// A JWT is a signed statement about the moment it was issued, and nothing
    /// consulted the database again until it expired an hour later. Archiving a
    /// user, or suspending one, therefore did nothing at all to whoever was
    /// already signed in: the phone in their hand kept listing slots and filing
    /// incidents against an account the admin had just removed, and the app had
    /// no way to know, because every request still came back 200.
    ///
    /// One database read per authenticated request buys the revocation the
    /// token format cannot give on its own. It is a single indexed lookup by
    /// primary key, on the same connection the request goes on to use.
    /// </remarks>
    public class AccountStateJwtEvents : JwtBearerEvents
    {
        internal const string FailureMessageKey = "auth:failure_message";
        internal const string FailureCodeKey = "auth:failure_code";

        /// <summary>The account is gone, or was never there.</summary>
        public const string AccountUnavailableCode = "account_unavailable";

        /// <summary>The account exists but is barred from signing in.</summary>
        public const string AccountBlockedCode = "account_blocked";

        /// <summary>Nothing wrong with the account — the token itself is no good.</summary>
        public const string SessionExpiredCode = "session_expired";

        public override async Task TokenValidated(TokenValidatedContext context)
        {
            var idClaim = context.Principal?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            // A registration session token names a session and no user — there
            // is no account yet to have an opinion about.
            if (!Guid.TryParse(idClaim, out var userId))
            {
                return;
            }

            var db = context.HttpContext.RequestServices.GetRequiredService<AppDbContext>();

            var account = await db.Set<User>()
                .AsNoTracking()
                .Where(u => u.Id == userId)
                .Select(u => new
                {
                    u.IsDeleted,
                    u.AccountStatus,
                    u.RegistrationStep
                })
                .FirstOrDefaultAsync(context.HttpContext.RequestAborted);

            if (account is null)
            {
                Reject(context, AccountUnavailableCode, "This account no longer exists.");
                return;
            }

            if (account.IsDeleted)
            {
                Reject(
                    context,
                    AccountUnavailableCode,
                    "This account has been deleted. Please contact the administrator.");
                return;
            }

            // Half-registered accounts run on a token of their own and are
            // supposed to be in a status that cannot sign in yet. Judging them
            // by the rules below would end the flow at the step that creates
            // the account.
            if (account.RegistrationStep != RegistrationStep.Completed)
            {
                return;
            }

            switch (account.AccountStatus)
            {
                case AccountStatus.Suspended:
                    Reject(
                        context,
                        AccountBlockedCode,
                        "Your account has been suspended. Please contact the administrator.");
                    return;

                case AccountStatus.Rejected:
                    Reject(
                        context,
                        AccountBlockedCode,
                        "Your registration was rejected, so this account can no longer be used.");
                    return;

                // Active is the ordinary case. PendingReview is deliberately let
                // through rather than rejected here: it is the default value of
                // the enum, so it is what a staff account inserted straight into
                // the database has, and the endpoints that actually care about
                // approval — parking, vehicles, passes — check for Active
                // themselves.
                default:
                    return;
            }
        }

        /// <summary>
        /// Answers a refused request with a readable sentence instead of an
        /// empty 401.
        /// </summary>
        /// <remarks>
        /// The client cannot act on a bare status code: "sign in again" and
        /// "this account is gone, start over" look identical over the wire, and
        /// the app showed nothing at all for either. The body says which, in the
        /// same <c>{ message }</c> shape every other failure here uses, plus a
        /// <c>code</c> so the app can decide where to leave the user without
        /// matching on English.
        /// </remarks>
        public override Task Challenge(JwtBearerChallengeContext context)
        {
            if (context.Response.HasStarted)
            {
                return Task.CompletedTask;
            }

            context.HandleResponse();

            var message = context.HttpContext.Items[FailureMessageKey] as string
                ?? "Your session has expired. Please sign in again.";
            var code = context.HttpContext.Items[FailureCodeKey] as string
                ?? SessionExpiredCode;

            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return context.Response.WriteAsJsonAsync(new { message, code });
        }

        private static void Reject(TokenValidatedContext context, string code, string message)
        {
            context.HttpContext.Items[FailureMessageKey] = message;
            context.HttpContext.Items[FailureCodeKey] = code;
            context.Fail(message);
        }
    }
}
