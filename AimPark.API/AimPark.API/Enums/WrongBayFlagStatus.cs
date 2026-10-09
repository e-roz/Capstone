namespace AimPark.API.Enums
{
    public enum WrongBayFlagStatus
    {
        /// <summary>Raised, and nobody has looked yet.</summary>
        Open,

        /// <summary>A guard went over and the wrong kind of vehicle was there.</summary>
        Confirmed,

        /// <summary>A guard went over and the bay was fine.</summary>
        FalseAlarm
    }
}
