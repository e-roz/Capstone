using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace AimPark.API.Tests;

/// <summary>
/// An incident is opened (Submitted -> UnderReview) and then decided once
/// (Resolved or Dismissed, with a note). A decision is final.
/// </summary>
public class IncidentReviewTests
{
    private static readonly Guid Admin = Guid.NewGuid();

    private sealed class Notices : INotificationService
    {
        public List<string> Titles { get; } = [];

        public Task NotifyUserAsync(Guid userId, NotificationType type, string title, string message,
            IDictionary<string, string>? data, CancellationToken ct)
        {
            Titles.Add(title);
            return Task.CompletedTask;
        }

        public Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct) => throw new NotImplementedException();
        public Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string message, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkAllReadAsync(Guid userId, UserRole role, CancellationToken ct) => throw new NotImplementedException();
    }

    private sealed record Fixture(AppDbContext Db, IncidentService Service, Notices Notices);

    private static Fixture NewFixture()
    {
        var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);
        var notices = new Notices();
        var service = new IncidentService(
            new Repository<Incident>(db), new Repository<IncidentEvidence>(db),
            fileStorage: null!, notices, db, NullLogger<IncidentService>.Instance);
        return new Fixture(db, service, notices);
    }

    private static async Task<(User User, Incident Incident)> SeedAsync(
        Fixture f, string name = "Lala", IncidentStatus status = IncidentStatus.Submitted)
    {
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = name, Email = $"{Guid.NewGuid():N}@x.test",
            Role = UserRole.User, AccountStatus = AccountStatus.Active
        };
        var incident = new Incident
        {
            ReportedByUserId = user.Id, Category = IncidentCategory.Accident,
            Description = "Hit near slot 14", Status = status
        };
        f.Db.AddRange(user, incident);
        await f.Db.SaveChangesAsync();
        return (user, incident);
    }

    [Fact]
    public async Task OpeningASubmittedReportStartsTheReviewAndTellsTheReporter()
    {
        var f = NewFixture();
        var (_, incident) = await SeedAsync(f);

        await f.Service.StartReviewAsync(incident.Id, Admin, default);

        var saved = await f.Db.Set<Incident>().AsNoTracking().SingleAsync();
        Assert.Equal(IncidentStatus.UnderReview, saved.Status);
        Assert.Single(f.Notices.Titles);
    }

    [Fact]
    public async Task OpeningItAgainDoesNotNotifyOrChangeAnything()
    {
        var f = NewFixture();
        var (_, incident) = await SeedAsync(f);

        await f.Service.StartReviewAsync(incident.Id, Admin, default);
        await f.Service.StartReviewAsync(incident.Id, Admin, default);

        Assert.Single(f.Notices.Titles);
    }

    [Fact]
    public async Task ResolvingRecordsTheDateAndTheNote()
    {
        var f = NewFixture();
        var (_, incident) = await SeedAsync(f, status: IncidentStatus.UnderReview);

        var result = await f.Service.ReviewAsync(
            incident.Id, Admin, new ReviewIncidentDto { Status = "Resolved", AdminNotes = "Checked the CCTV." }, default);

        Assert.IsType<OkObjectResult>(result.Result);
        var saved = await f.Db.Set<Incident>().AsNoTracking().SingleAsync();
        Assert.Equal(IncidentStatus.Resolved, saved.Status);
        Assert.Equal("Checked the CCTV.", saved.AdminNotes);
        Assert.NotNull(saved.ReviewedAt);
    }

    [Theory]
    [InlineData("Submitted")]
    [InlineData("UnderReview")]
    [InlineData("Withdrawn")]
    [InlineData("Nonsense")]
    public async Task OnlyResolvedOrDismissedCanBeSet(string status)
    {
        var f = NewFixture();
        var (_, incident) = await SeedAsync(f, status: IncidentStatus.UnderReview);

        var result = await f.Service.ReviewAsync(
            incident.Id, Admin, new ReviewIncidentDto { Status = status, AdminNotes = "note" }, default);

        Assert.IsType<BadRequestObjectResult>(result.Result);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("   ")]
    public async Task ADecisionNeedsANote(string? notes)
    {
        var f = NewFixture();
        var (_, incident) = await SeedAsync(f, status: IncidentStatus.UnderReview);

        var result = await f.Service.ReviewAsync(
            incident.Id, Admin, new ReviewIncidentDto { Status = "Dismissed", AdminNotes = notes }, default);

        Assert.IsType<BadRequestObjectResult>(result.Result);
        var saved = await f.Db.Set<Incident>().AsNoTracking().SingleAsync();
        Assert.Equal(IncidentStatus.UnderReview, saved.Status);
    }

    [Theory]
    [InlineData(IncidentStatus.Resolved)]
    [InlineData(IncidentStatus.Dismissed)]
    [InlineData(IncidentStatus.Withdrawn)]
    public async Task ADecidedOrWithdrawnReportCannotBeChanged(IncidentStatus current)
    {
        var f = NewFixture();
        var (_, incident) = await SeedAsync(f, status: current);

        var result = await f.Service.ReviewAsync(
            incident.Id, Admin, new ReviewIncidentDto { Status = "Resolved", AdminNotes = "again" }, default);

        Assert.IsType<BadRequestObjectResult>(result.Result);
        var saved = await f.Db.Set<Incident>().AsNoTracking().SingleAsync();
        Assert.Equal(current, saved.Status);
    }

    [Fact]
    public async Task SearchFindsEveryReportFromThatPerson()
    {
        var f = NewFixture();
        var (_, first) = await SeedAsync(f, "User 1");
        var user1 = first.ReportedByUserId;
        f.Db.Add(new Incident { ReportedByUserId = user1, Category = IncidentCategory.Theft, Description = "Bag" });
        await SeedAsync(f, "Mark");
        await f.Db.SaveChangesAsync();

        var result = await f.Service.ListAllAsync(null, "user 1", 1, 20, default);

        var page = Assert.IsType<IncidentListResponse>(Assert.IsType<OkObjectResult>(result.Result).Value);
        Assert.Equal(2, page.TotalCount);
        Assert.All(page.Incidents, i => Assert.Equal("User 1", i.ReportedByName));
    }

    [Fact]
    public async Task AnUnknownStatusFilterIsRefusedInsteadOfListingEverything()
    {
        var f = NewFixture();
        await SeedAsync(f);

        var result = await f.Service.ListAllAsync("Nonsense", null, 1, 20, default);

        Assert.IsType<BadRequestObjectResult>(result.Result);
    }
}
