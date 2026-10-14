using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Tests;

/// <summary>
/// A card's history is rebuilt from audit rows that are keyed by user, by
/// matching the "RfidTagId=..." text they store.
/// </summary>
public class RfidCardHistoryTests
{
    private static readonly Guid Admin = Guid.NewGuid();
    private static readonly Guid Ana = Guid.NewGuid();

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static AdminUserService Service(AppDbContext db) => new(
        new Repository<User>(db), new Repository<AdminAuditLog>(db), db, storage: null!, notificationService: null!);

    private static AdminAuditLog Log(string action, string? oldValue, string? newValue, string? reason, DateTime at) => new()
    {
        Id = Guid.NewGuid(),
        AdminUserId = Admin,
        TargetUserId = Ana,
        Action = action,
        OldValue = oldValue,
        NewValue = newValue,
        Reason = reason,
        CreatedAt = at
    };

    [Fact]
    public async Task History_matches_only_this_card_and_pairs_reinstate()
    {
        var db = NewDb();
        db.Users.Add(new User { Id = Admin, FullName = "Admin One", Email = "a@x.test" });
        db.Users.Add(new User { Id = Ana, FullName = "Ana Cruz", Email = "ana@x.test" });

        var t0 = new DateTime(2026, 10, 1, 8, 0, 0, DateTimeKind.Utc);
        db.AdminAuditLogs.AddRange(
            Log("AssignRfid", "RfidTagId=, RfidStatus=Unassigned", "RfidTagId=AB, RfidStatus=Active", null, t0),
            Log("RevokeRfid", "RfidTagId=AB, RfidStatus=Active", "RfidTagId=null, RfidStatus=Unassigned", "Other: wrong card", t0.AddDays(1)),
            Log("Reinstate", "AccountStatus=Revoked", "AccountStatus=Active", "Reinstated by assigning a card", t0.AddDays(2)),
            Log("AssignRfid", "RfidTagId=, RfidStatus=Revoked", "RfidTagId=AB, RfidStatus=Active", null, t0.AddDays(2)),
            // A different card whose ID starts with the same characters.
            Log("AssignRfid", "RfidTagId=, RfidStatus=Unassigned", "RfidTagId=AB12, RfidStatus=Active", null, t0.AddDays(3)),
            // A reinstate on another day, not tied to this card.
            Log("Reinstate", "AccountStatus=Revoked", "AccountStatus=Active", null, t0.AddDays(5)));
        await db.SaveChangesAsync();

        var result = await Service(db).GetRfidCardHistoryAsync("a:b", default);
        var entries = (List<RfidCardHistoryEntry>)((OkObjectResult)result.Result!).Value!;

        Assert.Equal(4, entries.Count);
        Assert.Equal(["AssignRfid", "Reinstate", "RevokeRfid", "AssignRfid"],
            entries.OrderByDescending(e => e.CreatedAt).ThenBy(e => e.Action).Select(e => e.Action));

        var revoke = entries.Single(e => e.Action == "RevokeRfid");
        Assert.Equal("Other", revoke.Reason);
        Assert.Equal("wrong card", revoke.Note);
        Assert.Equal("Admin One", revoke.ActorName);
        Assert.Equal("Ana Cruz", revoke.UserName);
    }

    [Theory]
    [InlineData("Lost", "Lost", null)]
    [InlineData("Stolen: left in a jeep", "Stolen", "left in a jeep")]
    [InlineData("ViolationLimit: Third accountable violation", "ViolationLimit", "Third accountable violation")]
    [InlineData("3", null, "3")]
    [InlineData("Card swapped", null, "Card swapped")]
    public void SplitRevokeReason_reads_the_stored_shape(string raw, string? reason, string? note)
    {
        Assert.Equal((reason, note), AdminUserService.SplitRevokeReason(raw));
    }
}
