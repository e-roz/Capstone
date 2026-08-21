using System.Diagnostics;
using AimPark.API.Data;
using AimPark.API.Entities;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Middleware
{
    /// <summary>
    /// Catches anything that escapes a controller, records it as a
    /// <see cref="SystemErrorLog"/>, and returns a JSON body the clients can
    /// actually read.
    ///
    /// This fixes a long-standing debugging trap as a side effect. Without a
    /// handler, an unhandled exception produced a bare 500 with no body — and,
    /// crucially, one that never ran the CORS response callbacks, so the browser
    /// reported it as a CORS failure. Hours got spent on the CORS policy for
    /// bugs that were really a null reference in a service. Registering this
    /// <em>inside</em> <c>UseCors</c> means the error response carries the same
    /// headers a success would, and the browser shows the real status.
    /// </summary>
    public static class GlobalExceptionHandler
    {
        /// <summary>
        /// A stack trace can run to tens of kilobytes, and the frames that
        /// identify a fault are the first ones. Storing the whole thing would
        /// let a single crash loop fill the table.
        /// </summary>
        private const int MaxStackTrace = 8000;

        public static void UseGlobalExceptionHandler(this WebApplication app)
        {
            app.UseExceptionHandler(errorApp =>
            {
                errorApp.Run(async context =>
                {
                    var feature = context.Features.Get<IExceptionHandlerFeature>();
                    var ex = feature?.Error;

                    var traceId = Activity.Current?.Id ?? context.TraceIdentifier;

                    context.Response.StatusCode = StatusCodes.Status500InternalServerError;
                    context.Response.ContentType = "application/json";

                    if (ex is not null)
                    {
                        // Logging must never be the reason a request dies, so the
                        // write is best-effort: if the database is the thing that
                        // is broken, the caller still gets a clean 500 rather than
                        // an exception raised while handling an exception.
                        try
                        {
                            var logger = context.RequestServices
                                .GetRequiredService<ILogger<AppDbContext>>();
                            logger.LogError(ex, "Unhandled exception on {Path}", context.Request.Path);

                            var db = context.RequestServices.GetRequiredService<AppDbContext>();

                            Guid? userId = null;
                            var sub = context.User?.FindFirst("sub")?.Value
                                      ?? context.User?.FindFirst(
                                          System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
                            if (Guid.TryParse(sub, out var parsed)) userId = parsed;

                            var stack = ex.StackTrace;
                            if (stack is { Length: > MaxStackTrace })
                                stack = stack[..MaxStackTrace];

                            db.SystemErrorLogs.Add(new SystemErrorLog
                            {
                                ErrorType = ex.GetType().Name,
                                Message = ex.Message,
                                StackTrace = stack,
                                Path = $"{context.Request.Method} {context.Request.Path}",
                                StatusCode = StatusCodes.Status500InternalServerError,
                                UserId = userId,
                                TraceId = traceId
                            });
                            await db.SaveChangesAsync();
                        }
                        catch
                        {
                            // Swallowed deliberately — see above.
                        }
                    }

                    // The message is deliberately generic. `traceId` is what ties
                    // a screenshot from a tester to the row in System Logs that
                    // explains it, without leaking a stack trace to the browser.
                    await context.Response.WriteAsJsonAsync(new
                    {
                        message = "Something went wrong on the server. "
                                + "Quote the trace ID if you report this.",
                        traceId
                    });
                });
            });
        }
    }
}
