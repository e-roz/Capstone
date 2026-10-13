namespace AimPark.API.Services
{
    /// <summary>Which way users inside and sensors detected disagree.</summary>
    public enum ParkingMismatch
    {
        /// <summary>More cars inside than sensors see: one is parked outside any bay.</summary>
        UnseenCar,

        /// <summary>More bays read taken than cars inside: one is taking two bays, or got in without a tap.</summary>
        ExtraBay
    }

    /// <summary>
    /// Decides when users inside against sensors detected has disagreed for
    /// long enough to send a guard to look.
    /// </summary>
    /// <remarks>
    /// A driver needs a few minutes between the gate and a bay, so a gap that
    /// has just opened proves nothing. It must hold the whole wait, in one
    /// direction, before anybody is told, and is told once: the same gap does
    /// not page the guard again every minute. It re-arms when the numbers
    /// agree again or the gap flips direction.
    ///
    /// While a sensor is silent the numbers cannot be compared (a car may sit
    /// in the bay it watches), so the clock is dropped rather than paused: the
    /// wait starts over once every sensor reads again.
    /// </remarks>
    public sealed class ParkingMismatchWatch
    {
        public static readonly TimeSpan DefaultWait = TimeSpan.FromMinutes(5);

        private readonly TimeSpan _wait;
        private ParkingMismatch? _direction;
        private DateTime _since;
        private bool _raised;

        public ParkingMismatchWatch(TimeSpan? wait = null) => _wait = wait ?? DefaultWait;

        /// <returns>The gap to tell security about, or null when there is nothing to say yet.</returns>
        public ParkingMismatch? Check(LotCount count, DateTime nowUtc)
        {
            ParkingMismatch? gap = !count.Comparable || count.UsersInside == count.SensorsDetected
                ? null
                : count.UsersInside > count.SensorsDetected ? ParkingMismatch.UnseenCar : ParkingMismatch.ExtraBay;

            if (gap is null || gap != _direction)
            {
                _direction = gap;
                _since = nowUtc;
                _raised = false;
                return null;
            }

            if (_raised || nowUtc - _since < _wait)
                return null;

            _raised = true;
            return gap;
        }
    }
}
