using AimPark.API.Helpers;
using Xunit;

namespace AimPark.API.Tests
{
    public class ReportPeriodTests
    {
        private static readonly DateOnly Today = new(2026, 10, 14);

        [Fact]
        public void A_morning_entry_belongs_to_the_philippine_day_not_the_utc_one()
        {
            // 6:00 AM in Baliuag is 22:00 the day before in UTC.
            var entry = new DateTime(2026, 10, 13, 22, 0, 0, DateTimeKind.Utc);

            Assert.Equal(new DateOnly(2026, 10, 14), PhilippineTime.LocalDate(entry));
            Assert.Equal(6, PhilippineTime.LocalHour(entry));
        }

        [Fact]
        public void A_philippine_day_starts_at_four_pm_utc_the_day_before()
        {
            var start = PhilippineTime.StartOfDayUtc(new DateOnly(2026, 10, 14));

            Assert.Equal(new DateTime(2026, 10, 13, 16, 0, 0, DateTimeKind.Utc), start);
        }

        [Fact]
        public void Days_counts_back_from_today_and_keeps_the_old_90_day_cap()
        {
            var week = ReportPeriod.From(new ReportQuery(7), Today);
            var huge = ReportPeriod.From(new ReportQuery(500), Today);

            Assert.Equal(new DateOnly(2026, 10, 8), week.First);
            Assert.Equal(Today, week.Last);
            Assert.Equal(90, huge.Days);
        }

        [Fact]
        public void A_range_is_inclusive_and_cannot_reach_into_the_future()
        {
            var range = ReportPeriod.From(
                new ReportQuery(14, new DateOnly(2026, 10, 10), new DateOnly(2026, 10, 30)), Today);

            Assert.Equal(new DateOnly(2026, 10, 10), range.First);
            Assert.Equal(Today, range.Last);
        }

        [Fact]
        public void A_backwards_range_is_put_the_right_way_round()
        {
            var range = ReportPeriod.From(
                new ReportQuery(14, new DateOnly(2026, 10, 12), new DateOnly(2026, 10, 9)), Today);

            Assert.Equal(new DateOnly(2026, 10, 9), range.First);
            Assert.Equal(new DateOnly(2026, 10, 12), range.Last);
        }

        [Fact]
        public void A_single_day_covers_exactly_twenty_four_hours()
        {
            var day = ReportPeriod.From(new ReportQuery(1, Today, Today), Today);

            Assert.Equal(1, day.Days);
            Assert.Equal(TimeSpan.FromHours(24), day.EndUtc - day.StartUtc);
            Assert.True(day.Contains(day.StartUtc));
            Assert.False(day.Contains(day.EndUtc));
        }

        [Fact]
        public void All_time_starts_from_the_first_record()
        {
            var all = ReportPeriod.From(new ReportQuery(14, AllTime: true), Today, new DateOnly(2026, 8, 1));

            Assert.Equal(new DateOnly(2026, 8, 1), all.First);
            Assert.Equal(Today, all.Last);
        }

        [Fact]
        public void All_time_with_no_records_is_just_today()
        {
            var all = ReportPeriod.From(new ReportQuery(14, AllTime: true), Today);

            Assert.Equal(1, all.Days);
        }

        [Theory]
        [InlineData(30, ReportGranularity.Day)]
        [InlineData(62, ReportGranularity.Day)]
        [InlineData(63, ReportGranularity.Week)]
        [InlineData(365, ReportGranularity.Week)]
        [InlineData(401, ReportGranularity.Month)]
        public void Long_ranges_are_cut_into_weeks_and_months(int days, ReportGranularity expected)
        {
            var range = new ReportPeriod(Today.AddDays(-(days - 1)), Today);

            Assert.Equal(expected, range.Granularity);
        }

        [Fact]
        public void A_week_starts_on_monday()
        {
            var range = new ReportPeriod(Today.AddDays(-99), Today);

            // 14 Oct 2026 is a Wednesday.
            Assert.Equal(new DateOnly(2026, 10, 12), range.BucketOf(Today));
            Assert.Equal(DayOfWeek.Monday, range.BucketOf(Today).DayOfWeek);
        }

        [Fact]
        public void Every_day_lands_in_exactly_one_listed_bucket()
        {
            var range = new ReportPeriod(Today.AddDays(-99), Today);
            var buckets = range.Buckets();

            Assert.Equal(buckets.Distinct().Count(), buckets.Count);
            for (var day = range.First; day <= range.Last; day = day.AddDays(1))
                Assert.Contains(range.BucketOf(day), buckets);
        }

        [Fact]
        public void Months_are_listed_even_when_empty()
        {
            var range = new ReportPeriod(new DateOnly(2025, 1, 15), Today);

            var buckets = range.Buckets();

            Assert.Equal(ReportGranularity.Month, range.Granularity);
            Assert.Equal(new DateOnly(2025, 1, 1), buckets[0]);
            Assert.Equal(new DateOnly(2026, 10, 1), buckets[^1]);
            Assert.Equal(22, buckets.Count);
        }
    }
}
