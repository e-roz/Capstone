using System.Globalization;
using System.Reflection;
using AimPark.API.Helpers;
using QRCoder;
using QuestPDF.Drawing;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace AimPark.API.Reports
{
    /// <summary>A headline number printed on a report and kept for the verify page.</summary>
    public record KeyFigure(string Label, string Value, string? Note = null);

    /// <summary>What sits around every report's body: who, what, when, and the proof.</summary>
    public record ReportFrame(
        string SchoolName,
        string Title,
        string PeriodText,
        string Number,
        string GeneratedByName,
        DateTime GeneratedAtUtc,
        string VerifyUrl,
        string SecondSignatureCaption);

    /// <summary>
    /// The one look every AimPark PDF shares, so six reports read as one set.
    /// </summary>
    /// <remarks>
    /// Black on white with one grey for supporting text: these are printed on
    /// office printers, often in black and white, and colour that carries
    /// meaning would be lost there.
    /// </remarks>
    public static class PdfLayout
    {
        public const string Font = "Inter";
        public const string Muted = "#5F5E5A";
        public const string Line = "#D3D1C7";
        public const string Tint = "#F1EFE8";
        public const string Bar = "#5F5E5A";

        private static readonly CultureInfo Ph = CultureInfo.GetCultureInfo("en-PH");

        /// <summary>
        /// Licence and fonts, once at start-up. The Render image has no fonts at
        /// all, so Inter ships inside the assembly rather than being looked up.
        /// </summary>
        public static void Configure()
        {
            QuestPDF.Settings.License = LicenseType.Community;
            QuestPDF.Settings.UseSystemFonts = false;

            var assembly = Assembly.GetExecutingAssembly();
            foreach (var name in assembly.GetManifestResourceNames()
                         .Where(n => n.Contains(".Resources.Fonts.") && n.EndsWith(".ttf")))
            {
                using var stream = assembly.GetManifestResourceStream(name)!;
                FontManager.RegisterFontFromStream(stream);
            }
        }

        // ── Formatting ──────────────────────────────────────────────────────

        public static string Money(decimal amount) => "₱" + amount.ToString("N2", Ph);
        public static string Count(int n) => n.ToString("N0", Ph);

        public static DateTime Local(DateTime utc) => utc.Add(PhilippineTime.Offset);
        public static string Date(DateTime utc) => Local(utc).ToString("MMM d, yyyy", Ph);
        public static string Stamp(DateTime utc) => Local(utc).ToString("MMM d, yyyy h:mm tt", Ph);
        public static string Time(DateTime utc) => Local(utc).ToString("h:mm tt", Ph);

        /// <summary>For table cells, where the year is already in the header: "Nov 3, 8:05 AM".</summary>
        public static string Short(DateTime utc) => Local(utc).ToString("MMM d, h:mm tt", Ph);
        public static string Day(DateOnly day) => day.ToString("MMM d, yyyy", Ph);

        public static string Period(DateOnly from, DateOnly to) =>
            from == to ? Day(from)
            : from.Year == to.Year ? $"{from.ToString("MMM d", Ph)} – {Day(to)}"
            : $"{Day(from)} – {Day(to)}";

        /// <summary>"+12% vs the 30 days before". Null when there is nothing to compare.</summary>
        public static string? Change(decimal now, decimal before, int days)
        {
            if (before == 0) return now == 0 ? null : "new this period";
            var pct = (int)Math.Round((now - before) / before * 100m);
            var sign = pct > 0 ? "+" : "";
            return $"{sign}{pct}% vs previous {days} days";
        }

        public static string Plural(int n, string one, string many) => $"{Count(n)} {(n == 1 ? one : many)}";

        // ── The page ────────────────────────────────────────────────────────

        public static byte[] Render(ReportFrame frame, Action<ColumnDescriptor> body) =>
            Build(frame, body).GeneratePdf();

        /// <summary>The document before it becomes bytes; a preview can turn it into images instead.</summary>
        public static Document Build(ReportFrame frame, Action<ColumnDescriptor> body)
        {
            var qr = QrPng(frame.VerifyUrl);

            return Document.Create(doc =>
            {
                doc.Page(page =>
                {
                    page.Size(PageSizes.A4);
                    page.Margin(36);
                    page.DefaultTextStyle(t => t.FontFamily(Font).FontSize(9).FontColor(Colors.Black));

                    page.Header().Element(c => Header(c, frame));

                    page.Content().PaddingVertical(10).Column(col =>
                    {
                        col.Spacing(12);
                        body(col);
                        col.Item().ShowEntire().PaddingTop(24).Element(c => Signatures(c, frame));
                    });

                    page.Footer().Element(c => Footer(c, frame, qr));
                });
            })
            .WithMetadata(new DocumentMetadata
            {
                Title = $"{frame.Title} – {frame.Number}",
                Author = frame.GeneratedByName,
                Creator = "AimPark",
                Producer = "AimPark"
            });
        }

        private static void Header(IContainer c, ReportFrame f)
        {
            c.BorderBottom(1.5f).BorderColor(Colors.Black).PaddingBottom(8).Row(row =>
            {
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text(f.SchoolName).FontSize(13).SemiBold();
                    col.Item().Text("AimPark Smart Parking System").FontColor(Muted);
                });
                row.RelativeItem().AlignRight().Column(col =>
                {
                    col.Item().AlignRight().Text(f.Title).FontSize(12).SemiBold();
                    col.Item().AlignRight().Text(f.PeriodText).FontColor(Muted);
                    col.Item().AlignRight().Text($"Report no. {f.Number}").FontColor(Muted);
                });
            });
        }

        private static void Signatures(IContainer c, ReportFrame f)
        {
            c.Row(row =>
            {
                row.RelativeItem().Column(col =>
                {
                    col.Item().Height(28);
                    col.Item().BorderTop(0.75f).PaddingTop(3).Text(f.GeneratedByName).SemiBold();
                    col.Item().Text("Prepared by").FontColor(Muted);
                });
                row.ConstantItem(40);
                row.RelativeItem().Column(col =>
                {
                    col.Item().Height(28);
                    col.Item().BorderTop(0.75f).PaddingTop(3).Text(" ");
                    col.Item().Text(f.SecondSignatureCaption).FontColor(Muted);
                });
            });
        }

        private static void Footer(IContainer c, ReportFrame f, byte[] qr)
        {
            c.BorderTop(0.5f).BorderColor(Line).PaddingTop(6).Row(row =>
            {
                row.RelativeItem().Column(col =>
                {
                    col.Item().Text($"Generated by {f.GeneratedByName} · {Stamp(f.GeneratedAtUtc)}")
                        .FontSize(8).FontColor(Muted);
                    col.Item().Text("Scan the code to check this report against the system's own record.")
                        .FontSize(8).FontColor(Muted);
                    col.Item().Text(t =>
                    {
                        t.DefaultTextStyle(s => s.FontSize(8).FontColor(Muted));
                        t.Span("Page ");
                        t.CurrentPageNumber();
                        t.Span(" of ");
                        t.TotalPages();
                    });
                });
                row.ConstantItem(46).Image(qr);
            });
        }

        private static byte[] QrPng(string url)
        {
            using var generator = new QRCodeGenerator();
            using var data = generator.CreateQrCode(url, QRCodeGenerator.ECCLevel.M);
            return new PngByteQRCode(data).GetGraphic(10);
        }

        // ── Building blocks for report bodies ───────────────────────────────

        public static void Section(ColumnDescriptor col, string title, string? subtitle = null)
        {
            col.Item().PaddingTop(4).BorderBottom(0.5f).BorderColor(Line).PaddingBottom(3).Row(row =>
            {
                row.RelativeItem().Text(title).FontSize(11).SemiBold();
                if (subtitle is not null)
                    row.AutoItem().AlignBottom().Text(subtitle).FontSize(8).FontColor(Muted);
            });
        }

        /// <summary>The grey boxes of headline numbers, four to a row.</summary>
        public static void Figures(ColumnDescriptor col, IReadOnlyList<KeyFigure> figures)
        {
            foreach (var chunk in figures.Chunk(4))
            {
                col.Item().Row(row =>
                {
                    row.Spacing(8);
                    foreach (var f in chunk)
                    {
                        row.RelativeItem().Background(Tint).Padding(8).Column(box =>
                        {
                            box.Item().Text(f.Label).FontSize(8).FontColor(Muted);
                            box.Item().Text(f.Value).FontSize(15).SemiBold();
                            if (f.Note is not null)
                                box.Item().Text(f.Note).FontSize(7.5f).FontColor(Muted);
                        });
                    }
                    for (var i = chunk.Length; i < 4; i++) row.RelativeItem();
                });
            }
        }

        /// <summary>Horizontal bars: one row per label, longest bar = largest value.</summary>
        public static void Bars(ColumnDescriptor col, IReadOnlyList<(string Label, double Value, string Shown)> rows)
        {
            var max = rows.Count == 0 ? 0 : rows.Max(r => r.Value);
            col.Item().Column(bars =>
            {
                bars.Spacing(3);
                foreach (var (label, value, shown) in rows)
                {
                    bars.Item().Row(row =>
                    {
                        row.ConstantItem(80).Text(label).FontSize(8).FontColor(Muted);
                        row.RelativeItem().AlignMiddle().Height(9).Row(track =>
                        {
                            if (max <= 0 || value <= 0)
                            {
                                track.RelativeItem();
                                return;
                            }
                            track.RelativeItem((float)value).Background(Bar);
                            if (value < max) track.RelativeItem((float)(max - value));
                        });
                        row.ConstantItem(70).AlignRight().Text(shown).FontSize(8);
                    });
                }
            });
        }

        /// <summary>A two-column label/value list, for small breakdowns.</summary>
        public static void Pairs(ColumnDescriptor col, IEnumerable<(string Label, string Value)> pairs)
        {
            col.Item().Table(t =>
            {
                t.ColumnsDefinition(c =>
                {
                    c.RelativeColumn(3);
                    c.RelativeColumn(1);
                });
                foreach (var (label, value) in pairs)
                {
                    t.Cell().Element(BodyCell).Text(label);
                    t.Cell().Element(BodyCell).AlignRight().Text(value);
                }
            });
        }

        /// <summary>
        /// A data table. <paramref name="widths"/> are relative; a column whose
        /// header starts with ">" is right-aligned (the ">" is not printed).
        /// The header repeats at the top of every page the table runs onto.
        /// </summary>
        public static void Table(
            ColumnDescriptor col,
            IReadOnlyList<string> headers,
            IReadOnlyList<float> widths,
            IEnumerable<IReadOnlyList<string>> rows,
            IReadOnlyList<string>? totalRow = null,
            string empty = "Nothing recorded for this period.")
        {
            var right = headers.Select(h => h.StartsWith('>')).ToArray();
            var list = rows.ToList();

            if (list.Count == 0)
            {
                col.Item().PaddingVertical(6).Text(empty).FontColor(Muted).Italic();
                return;
            }

            col.Item().Table(t =>
            {
                t.ColumnsDefinition(c =>
                {
                    foreach (var w in widths) c.RelativeColumn(w);
                });

                t.Header(h =>
                {
                    for (var i = 0; i < headers.Count; i++)
                    {
                        var cell = h.Cell().BorderBottom(1).BorderColor(Colors.Black).PaddingVertical(3).PaddingHorizontal(3);
                        if (right[i]) cell = cell.AlignRight();
                        cell.Text(headers[i].TrimStart('>')).FontSize(8).SemiBold();
                    }
                });

                foreach (var r in list)
                {
                    for (var i = 0; i < headers.Count; i++)
                    {
                        var cell = t.Cell().Element(BodyCell);
                        if (right[i]) cell = cell.AlignRight();
                        cell.Text(i < r.Count ? r[i] : "").FontSize(8);
                    }
                }

                if (totalRow is not null)
                {
                    for (var i = 0; i < headers.Count; i++)
                    {
                        var cell = t.Cell().BorderTop(1).BorderColor(Colors.Black).PaddingVertical(3).PaddingHorizontal(3);
                        if (right[i]) cell = cell.AlignRight();
                        cell.Text(i < totalRow.Count ? totalRow[i] : "").FontSize(8).SemiBold();
                    }
                }
            });
        }

        public static void Note(ColumnDescriptor col, string text) =>
            col.Item().Text(text).FontSize(8).FontColor(Muted);

        private static IContainer BodyCell(IContainer c) =>
            c.BorderBottom(0.5f).BorderColor(Line).PaddingVertical(3).PaddingHorizontal(3);
    }
}
