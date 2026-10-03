namespace AimPark.API.Enums
{
    /// <summary>Whether a registered visitor card may be lent out.</summary>
    public enum VisitorCardState
    {
        /// <summary>In the drawer or out with a visitor. Opens the barrier once a pass is on it.</summary>
        Active,

        /// <summary>
        /// Lost, stolen or broken. Refused at the gate and at the desk, but kept
        /// so the past passes on it still say which card they were.
        /// </summary>
        Blocked
    }
}
