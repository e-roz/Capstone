namespace AimPark.API.DTOs
{
    public class ReportsSummaryResponse
    {
        public int TotalUsers { get; set; }
        public int ActiveUsers { get; set; }
        public int TotalSlots { get; set; }

        /// <summary>
        /// Bays a car could use: not out of service and not without a sensor
        /// signal. Free and occupied below are both counted against this, so
        /// <c>AvailableSlots + OccupiedSlots == UsableSlots</c> always.
        /// </summary>
        public int UsableSlots { get; set; }
        public int OccupiedSlots { get; set; }

        /// <summary>
        /// Free bays by the rule the gates use (<see cref="Services.ParkingCapacity"/>):
        /// working bays minus the cars that have tapped in. Every screen reads
        /// this one number.
        /// </summary>
        public int AvailableSlots { get; set; }

        public int UsableFourWheel { get; set; }
        public int FreeFourWheel { get; set; }
        public int UsableMotorcycle { get; set; }
        public int FreeMotorcycle { get; set; }

        /// <summary>Bays whose sensor has stopped reading.</summary>
        public int NoSignalSlots { get; set; }

        /// <summary>
        /// Bays that exist but cannot be parked in. Reported separately so the
        /// panel can show real capacity rather than counting a broken bay as
        /// free space.
        /// </summary>
        public int OutOfServiceSlots { get; set; }

        /// <summary>The period the figures below that follow it were counted over.</summary>
        public ReportPeriodInfo Period { get; set; } = new();

        /// <summary>Sessions that started today, the Philippine day.</summary>
        public int SessionsToday { get; set; }
        public int SessionsInPeriod { get; set; }

        /// <summary>Paid in the period: parking fees and violation penalties together.</summary>
        public decimal RevenueCollected { get; set; }
        public decimal FeesCollected { get; set; }
        public decimal FinesCollected { get; set; }

        /// <summary>Owed right now, whatever the period: not yet paid, or checkout started and not finished.</summary>
        public decimal RevenuePending { get; set; }
        public decimal FeesPending { get; set; }
        public decimal FinesPending { get; set; }

        public int ViolationsIssued { get; set; }
        public int OpenIncidents { get; set; }

        /// <summary>
        /// Taps refused today that need a look: a card nobody holds, or a plate
        /// that is not the card holder's. Camera failures, a full lot and double
        /// taps are routine and not counted.
        /// </summary>
        public int SeriousDenialsToday { get; set; }
    }

    /// <summary>The Philippine days a report covers, and how it was cut.</summary>
    public class ReportPeriodInfo
    {
        public DateOnly From { get; set; }
        public DateOnly To { get; set; }

        /// <summary>"day", "week" or "month": what one point on a trend stands for.</summary>
        public string Granularity { get; set; } = "day";
    }

    public class DailyCountPoint
    {
        public DateTime Date { get; set; }
        public int Count { get; set; }
    }

    public class OccupancyTrendResponse
    {
        public ReportPeriodInfo Period { get; set; } = new();
        public List<DailyCountPoint> Points { get; set; } = [];
    }

    /// <summary>
    /// Vehicles in and out on one day, and how many visitors were among them.
    /// </summary>
    /// <remarks>
    /// Entries and exits are counted separately rather than netted off. A day
    /// where 40 cars came in and 40 left is not the same day as one where 5 came
    /// in and 5 left, and a single "movements" number cannot tell them apart.
    /// </remarks>
    public class EntryExitPoint
    {
        public DateTime Date { get; set; }
        public int Entries { get; set; }
        public int Exits { get; set; }

        /// <summary>Entries made on a lent visitor card, of the total above.</summary>
        public int VisitorEntries { get; set; }
    }

    public class EntryExitReportResponse
    {
        public ReportPeriodInfo Period { get; set; } = new();
        public List<EntryExitPoint> Points { get; set; } = [];

        public int TotalEntries { get; set; }
        public int TotalExits { get; set; }
        public int TotalVisitorEntries { get; set; }

        /// <summary>
        /// Sessions opened in the window that have no exit recorded. A handful
        /// is normal - cars still parked. A large number means the exit half of
        /// the gate is not being used.
        /// </summary>
        public int StillOpen { get; set; }
    }

    public class PeakHourPoint
    {
        public int Hour { get; set; }
        public int Count { get; set; }
    }

    public class PeakHoursResponse
    {
        public ReportPeriodInfo Period { get; set; } = new();

        /// <summary>Hours are the Philippine hour of the day.</summary>
        public List<PeakHourPoint> Points { get; set; } = [];
    }

    public class ViolationStatusCount
    {
        public string Status { get; set; } = string.Empty;
        public int Count { get; set; }
    }

    public class ViolationRuleCount
    {
        public string RuleTitle { get; set; } = string.Empty;
        public int Count { get; set; }
    }

    public class ViolationBreakdownResponse
    {
        public List<ViolationStatusCount> ByStatus { get; set; } = [];
        public List<ViolationRuleCount> ByRule { get; set; } = [];
    }

    public class RevenuePoint
    {
        public DateTime Date { get; set; }

        /// <summary>Fees plus fines.</summary>
        public decimal Amount { get; set; }
        public decimal Fees { get; set; }
        public decimal Fines { get; set; }
    }

    public class RevenueTrendResponse
    {
        public ReportPeriodInfo Period { get; set; } = new();
        public List<RevenuePoint> Points { get; set; } = [];
    }
}
