namespace AimPark.API.Enums
{
    /// <summary>
    /// What kind of rule a policy is. The capstone document asks Policy &amp; Rule
    /// Management to manage "parking regulations, violations, penalties and
    /// categories"; this is the categories part.
    ///
    /// An enum rather than free text so Reports can group by it without having
    /// to reconcile "Parking" against "parking " typed a month apart.
    /// </summary>
    public enum PolicyCategory
    {
        /// <summary>Bad parking itself — wrong bay, double-parked, over the line.</summary>
        Parking = 0,

        /// <summary>Entry/exit and RFID misuse — tailgating, lending a card.</summary>
        Access = 1,

        /// <summary>Moving offences inside the campus grounds — speeding, wrong way.</summary>
        Conduct = 2,

        /// <summary>Registration and document problems — expired OR, unregistered plate.</summary>
        Documentation = 3,

        /// <summary>Anything that does not fit the four above.</summary>
        Other = 4
    }
}
