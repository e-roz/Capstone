namespace AimPark.API.DTOs
{
    public class ReportsSummaryResponse
    {
        public int TotalUsers { get; set; }
        public int ActiveUsers { get; set; }
        public int TotalSlots { get; set; }
        public int OccupiedSlots { get; set; }
        public int AvailableSlots { get; set; }

        /// <summary>
        /// Bays that exist but cannot be parked in. Reported separately so the
        /// panel can show real capacity rather than counting a broken bay as
        /// free space.
        /// </summary>
        public int OutOfServiceSlots { get; set; }
        public int SessionsToday { get; set; }
        public decimal RevenueCollected { get; set; }
        public decimal RevenuePending { get; set; }
        public int ViolationsIssued { get; set; }
        public int OpenIncidents { get; set; }
    }

    public class DailyCountPoint
    {
        public DateTime Date { get; set; }
        public int Count { get; set; }
    }

    public class OccupancyTrendResponse
    {
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
        public decimal Amount { get; set; }
    }

    public class RevenueTrendResponse
    {
        public List<RevenuePoint> Points { get; set; } = [];
    }
}
