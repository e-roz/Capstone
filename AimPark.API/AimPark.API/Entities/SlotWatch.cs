namespace AimPark.API.Entities
{
    /// <summary>
    /// A user who asked to be told when a bay frees up in a full lot.
    /// </summary>
    /// <remarks>
    /// "A slot just opened" used to go to every user, including the ones
    /// already parked inside and the ones not coming today. Now it only goes
    /// to people who pressed "Notify me", and each watch is used up by the
    /// first opening it hears about — the next time the lot fills, they ask
    /// again if they still care.
    ///
    /// Cloud-only. The site server never reads this; it hands the push to the
    /// cloud, which looks the watchers up here.
    /// </remarks>
    public class SlotWatch
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid UserId { get; set; }
        public User User { get; set; } = null!;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
