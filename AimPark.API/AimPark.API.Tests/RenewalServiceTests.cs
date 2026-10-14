using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Tests;

/// <summary>
/// Renewing a licence or a registration after approval: the user uploads it, an
/// admin decides, and nothing on the account changes until then.
/// </summary>
public class RenewalServiceTests
{
    private static readonly DateTime Today = DateTime.UtcNow.Date;

    private sealed record Setup(
        AppDbContext Db, RenewalService Service, User User, Vehicle Car, Vehicle EBike);

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static async Task<Setup> SetupAsync(AccountStatus status = AccountStatus.Active)
    {
        var db = NewDb();
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = "Juan Dela Cruz", Email = "j@x.test", Role = UserRole.User,
            AccountStatus = status, LicenseValidThrough = Today.AddDays(10)
        };
        var car = new Vehicle
        {
            UserId = user.Id, PlateNumber = "ABC1234", VehicleType = VehicleType.Car, Color = "Black",
            RegistrationValidThrough = Today.AddDays(20)
        };
        var ebike = new Vehicle
        {
            UserId = user.Id, PlateNumber = "EB0001", VehicleType = VehicleType.Motorcycle, Color = "Red",
            IsEBike = true
        };
        db.AddRange(user, car, ebike);
        await db.SaveChangesAsync();

        var service = new RenewalService(
            new Repository<User>(db), new Repository<Vehicle>(db), new Repository<Document>(db),
            new Repository<DocumentRenewal>(db), new Repository<AdminAuditLog>(db),
            new FakeStorage(), new DocumentExtractionService(), new QuietNotifications());

        return new Setup(db, service, user, car, ebike);
    }

    private static IFormFile Photo(string name = "renewed.jpg")
    {
        var bytes = new byte[] { 1, 2, 3, 4 };
        return new FormFile(new MemoryStream(bytes), 0, bytes.Length, "Document", name);
    }

    private static T Ok<T>(ActionResult<T> result) => (T)((OkObjectResult)result.Result!).Value!;

    private static int Status<T>(ActionResult<T> result) => result.Result is ObjectResult o ? o.StatusCode ?? 200 : 200;

    private static async Task<DocumentRenewal> DraftAsync(
        Setup s, DocumentType kind = DocumentType.License, Guid? vehicleId = null)
    {
        var doc = new Document { Type = kind, FileName = "x.jpg", FilePath = "p/x.jpg", UserId = s.User.Id };
        var renewal = new DocumentRenewal
        {
            UserId = s.User.Id, VehicleId = vehicleId, Type = kind, DocumentId = doc.Id, Status = RenewalStatus.Draft
        };
        s.Db.AddRange(doc, renewal);
        await s.Db.SaveChangesAsync();
        return renewal;
    }

    private static async Task<DocumentRenewal> PendingAsync(
        Setup s, DateTime newExpiry, DocumentType kind = DocumentType.License, Guid? vehicleId = null)
    {
        var renewal = await DraftAsync(s, kind, vehicleId);
        renewal.NewExpiry = newExpiry;
        renewal.Status = RenewalStatus.Pending;
        await s.Db.SaveChangesAsync();
        return renewal;
    }

    // ── Scanning ───────────────────────────────────────────────────────────

    [Fact]
    public async Task ScanningALicenceMakesADraftAndKeepsTheFile()
    {
        var s = await SetupAsync();

        var result = await s.Service.ScanAsync(
            new RenewalUploadDto { Document = Photo(), Kind = "License" }, s.User.Id, default);

        var response = Ok(result);
        Assert.True(response.CanContinue);
        var renewal = await s.Db.DocumentRenewals.SingleAsync();
        Assert.Equal(RenewalStatus.Draft, renewal.Status);
        Assert.Null(renewal.VehicleId);
        Assert.Equal(DocumentType.License, (await s.Db.Documents.SingleAsync()).Type);
    }

    [Fact]
    public async Task AccountThatIsNotApprovedCannotRenew()
    {
        var s = await SetupAsync(AccountStatus.PendingReview);

        var result = await s.Service.ScanAsync(
            new RenewalUploadDto { Document = Photo(), Kind = "License" }, s.User.Id, default);

        Assert.Equal(400, Status(result));
        Assert.Empty(s.Db.DocumentRenewals);
    }

    [Fact]
    public async Task ARegistrationNeedsAVehicleOfYours()
    {
        var s = await SetupAsync();

        var none = await s.Service.ScanAsync(
            new RenewalUploadDto { Document = Photo(), Kind = "OfficialReceipt" }, s.User.Id, default);
        var someoneElses = await s.Service.ScanAsync(
            new RenewalUploadDto { Document = Photo(), Kind = "OfficialReceipt", VehicleId = Guid.NewGuid() },
            s.User.Id, default);

        Assert.Equal(400, Status(none));
        Assert.Equal(404, Status(someoneElses));
    }

    [Fact]
    public async Task AnEBikeHasNoRegistrationToRenew()
    {
        var s = await SetupAsync();

        var result = await s.Service.ScanAsync(
            new RenewalUploadDto { Document = Photo(), Kind = "OfficialReceipt", VehicleId = s.EBike.Id },
            s.User.Id, default);

        Assert.Equal(400, Status(result));
    }

    [Fact]
    public async Task ARenewalAlreadyWaitingBlocksAnotherForTheSameDocument()
    {
        var s = await SetupAsync();
        await PendingAsync(s, Today.AddYears(1));

        var result = await s.Service.ScanAsync(
            new RenewalUploadDto { Document = Photo(), Kind = "License" }, s.User.Id, default);

        Assert.Equal(400, Status(result));
    }

    [Fact]
    public async Task ScanningAgainReplacesTheEarlierDraft()
    {
        var s = await SetupAsync();
        var dto = () => new RenewalUploadDto { Document = Photo(), Kind = "License" };

        await s.Service.ScanAsync(dto(), s.User.Id, default);
        await s.Service.ScanAsync(dto(), s.User.Id, default);

        Assert.Single(s.Db.DocumentRenewals);
    }

    // ── Submitting ─────────────────────────────────────────────────────────

    [Fact]
    public async Task SubmittingSendsItForReviewWithoutChangingTheLicence()
    {
        var s = await SetupAsync();
        var draft = await DraftAsync(s);

        var result = await s.Service.SubmitAsync(
            draft.Id, new SubmitRenewalDto { Expiry = Today.AddYears(5) }, s.User.Id, default);

        Assert.Equal(200, Status(result));
        var saved = await s.Db.DocumentRenewals.SingleAsync();
        Assert.Equal(RenewalStatus.Pending, saved.Status);
        Assert.Equal(Today.AddYears(5), saved.NewExpiry);
        Assert.Equal(Today.AddDays(10), (await s.Db.Users.SingleAsync()).LicenseValidThrough);
    }

    [Fact]
    public async Task ADateThatHasPassedIsNotARenewal()
    {
        var s = await SetupAsync();
        var draft = await DraftAsync(s);

        var result = await s.Service.SubmitAsync(
            draft.Id, new SubmitRenewalDto { Expiry = Today.AddDays(-1) }, s.User.Id, default);

        Assert.Equal(400, Status(result));
    }

    [Fact]
    public async Task ADateNoLaterThanTheOneOnFileIsTheSameDocumentAgain()
    {
        var s = await SetupAsync();
        var draft = await DraftAsync(s);

        var result = await s.Service.SubmitAsync(
            draft.Id, new SubmitRenewalDto { Expiry = Today.AddDays(10) }, s.User.Id, default);

        Assert.Equal(400, Status(result));
    }

    [Fact]
    public async Task SomeoneElsesRenewalCannotBeSubmitted()
    {
        var s = await SetupAsync();
        var draft = await DraftAsync(s);

        var result = await s.Service.SubmitAsync(
            draft.Id, new SubmitRenewalDto { Expiry = Today.AddYears(5) }, Guid.NewGuid(), default);

        Assert.Equal(404, Status(result));
    }

    // ── The admin ──────────────────────────────────────────────────────────

    [Fact]
    public async Task ApprovingALicenceReplacesItsDateAndLeavesTheAccountAlone()
    {
        var s = await SetupAsync();
        var renewal = await PendingAsync(s, Today.AddYears(5));

        var result = await s.Service.ApproveAsync(renewal.Id, Guid.NewGuid(), default);

        Assert.Equal(200, Status(result));
        var user = await s.Db.Users.SingleAsync();
        Assert.Equal(Today.AddYears(5), user.LicenseValidThrough);
        Assert.Equal(AccountStatus.Active, user.AccountStatus);
        Assert.Equal(RenewalStatus.Approved, (await s.Db.DocumentRenewals.SingleAsync()).Status);
        Assert.Equal("RenewalApprove", (await s.Db.AdminAuditLogs.SingleAsync()).Action);
    }

    [Fact]
    public async Task ApprovingARegistrationChangesThatVehicleOnly()
    {
        var s = await SetupAsync();
        var renewal = await PendingAsync(s, Today.AddYears(1), DocumentType.OfficialReceipt, s.Car.Id);

        await s.Service.ApproveAsync(renewal.Id, Guid.NewGuid(), default);

        Assert.Equal(Today.AddYears(1), (await s.Db.vehicles.SingleAsync(v => v.Id == s.Car.Id)).RegistrationValidThrough);
        Assert.Equal(Today.AddDays(10), (await s.Db.Users.SingleAsync()).LicenseValidThrough);
    }

    [Fact]
    public async Task OnlyAWaitingRenewalCanBeApproved()
    {
        var s = await SetupAsync();
        var draft = await DraftAsync(s);

        var result = await s.Service.ApproveAsync(draft.Id, Guid.NewGuid(), default);

        Assert.Equal(400, Status(result));
        Assert.Equal(Today.AddDays(10), (await s.Db.Users.SingleAsync()).LicenseValidThrough);
    }

    [Fact]
    public async Task RejectingNeedsAReasonAndKeepsTheOldDate()
    {
        var s = await SetupAsync();
        var renewal = await PendingAsync(s, Today.AddYears(5));

        var noReason = await s.Service.RejectAsync(renewal.Id, Guid.NewGuid(), new RejectRenewalDto(), default);
        Assert.Equal(400, Status(noReason));

        var rejected = await s.Service.RejectAsync(
            renewal.Id, Guid.NewGuid(), new RejectRenewalDto { Reason = "Too blurry." }, default);

        Assert.Equal(200, Status(rejected));
        var saved = await s.Db.DocumentRenewals.SingleAsync();
        Assert.Equal(RenewalStatus.Rejected, saved.Status);
        Assert.Equal("Too blurry.", saved.RejectReason);
        Assert.Equal(Today.AddDays(10), (await s.Db.Users.SingleAsync()).LicenseValidThrough);
    }

    // ── What the app and the queue see ─────────────────────────────────────

    [Fact]
    public async Task TheAppSeesWhatIsWaitingOrTurnedDownAndNothingElse()
    {
        var s = await SetupAsync();
        await PendingAsync(s, Today.AddYears(5));
        var approved = await PendingAsync(s, Today.AddYears(1), DocumentType.OfficialReceipt, s.Car.Id);
        approved.Status = RenewalStatus.Approved;
        await s.Db.SaveChangesAsync();

        var mine = Ok(await s.Service.GetMineAsync(s.User.Id, default));

        var only = Assert.Single(mine);
        Assert.Equal("License", only.Kind);
        Assert.Equal("Pending", only.Status);
    }

    [Fact]
    public async Task TheQueueShowsTheDateOnFileNextToTheNewOne()
    {
        var s = await SetupAsync();
        await PendingAsync(s, Today.AddYears(5));

        var queue = Ok(await s.Service.GetForAdminAsync("Pending", default));

        var row = Assert.Single(queue);
        Assert.Equal("Juan Dela Cruz", row.FullName);
        Assert.Equal(Today.AddDays(10), row.CurrentExpiry);
        Assert.Equal(Today.AddYears(5), row.NewExpiry);
        Assert.StartsWith("url:", row.FileUrl);
    }

    // ── Stubs ──────────────────────────────────────────────────────────────

    private sealed class FakeStorage : IFileStorageService
    {
        public Task<string> SaveFileAsync(Guid userId, string documentType, IFormFile file, CancellationToken ct = default) =>
            Task.FromResult($"{userId}/{documentType}/{file.FileName}");

        public Task<string> SaveFileAsync(string objectPath, IFormFile file, CancellationToken ct = default) =>
            Task.FromResult(objectPath);

        public Task<string> GetFileUrlAsync(string filePath, CancellationToken ct = default) =>
            Task.FromResult($"url:{filePath}");

        public Task EnsureBucketAsync(string bucket, CancellationToken ct = default) => throw new NotImplementedException();
        public Task<string> SaveBytesAsync(string bucket, string objectPath, byte[] content, string contentType, CancellationToken ct = default) => throw new NotImplementedException();
        public Task<byte[]?> DownloadAsync(string bucket, string objectPath, CancellationToken ct = default) => throw new NotImplementedException();
        public Task<IReadOnlyList<StoredObject>> ListAsync(string bucket, string prefix = "", CancellationToken ct = default) => throw new NotImplementedException();
        public Task<int> DeleteAsync(string bucket, IReadOnlyCollection<string> objectPaths, CancellationToken ct = default) => throw new NotImplementedException();
    }

    private sealed class QuietNotifications : INotificationService
    {
        public Task NotifyUserAsync(Guid userId, NotificationType type, string title, string message,
            IDictionary<string, string>? data, CancellationToken ct) => Task.CompletedTask;

        public Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct) => throw new NotImplementedException();
        public Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string message, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListSystemAsync(DateTime? from, DateTime? to, int take, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkAllReadAsync(Guid userId, UserRole role, CancellationToken ct) => throw new NotImplementedException();
    }
}
