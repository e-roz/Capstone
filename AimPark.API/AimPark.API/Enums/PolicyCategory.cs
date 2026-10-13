namespace AimPark.API.Enums
{
    /// <summary>
    /// What kind of rule a policy is. The capstone document asks Policy &amp; Rule
    /// Management to manage "parking regulations, violations, penalties and
    /// categories"; this is the categories part.
    ///
    /// An enum rather than free text so Reports can group by it without having
    /// to reconcile "Parking" against "parking " typed a month apart.
    ///
    /// Two kinds are enough: where the car was left, and how the person
    /// behaved. Access, Documentation and Other used to be separate and were
    /// folded into Conduct.
    /// </summary>
    public enum PolicyCategory
    {
        /// <summary>Bad parking itself — wrong bay, double-parked, over the line.</summary>
        Parking = 0,

        /// <summary>
        /// How the person behaved — tailgating, lending a card, damage, theft,
        /// expired papers.
        /// </summary>
        Conduct = 2
    }
}
