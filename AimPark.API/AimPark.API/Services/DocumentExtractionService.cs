using AimPark.API.DTOs;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using System.Text.RegularExpressions;

namespace AimPark.API.Services
{
    public partial class DocumentExtractionService : IDocumentExtractionService
    {
        // Philippine plates run from six characters up; the ceiling allows for a
        // stray character OCR appended rather than rejecting a real plate.
        private const int MinPlateLength = 5;
        private const int MaxPlateLength = 8;

        public ExtractedValuesDto Extract(
            OcrPayloadDto? identity,
            OcrPayloadDto? license,
            OcrPayloadDto? receipt,
            string? accountName)
        {
            var result = new ExtractedValuesDto();

            var identityLines = Prepare(identity);
            var licenseLines = Prepare(license);
            var receiptLines = Prepare(receipt);

            ExtractSchoolForm(identityLines, result);

            result.LicenseName = ValueAfterAnyLabel(
                licenseLines, DocumentLabels.License.Name, allowNextLine: true, preferNextLine: true);
            result.LicenseExpiry = DateExtraction.FindFullDate(
                ValueAfterAnyLabel(
                    licenseLines, DocumentLabels.License.Expiry, allowNextLine: true, preferNextLine: true));

            // Faculty and staff have no RAF, so the only trusted name to search
            // with is the one they typed at signup. Students always prefer the
            // RAF reading — it is read from labelled cells, not free text.
            var expectedName = result.StudentName ?? NameFormat.FromTypedFullName(accountName);
            result.LicenseNameFound = NameLocator.AppearsIn(licenseLines, expectedName);

            var plate = ExtractPlate(receiptLines);
            result.PlateNumber = plate;
            result.RegistrationExpiry = ExtractRegistrationExpiry(receiptLines, plate, result);
            result.VehicleType = ExtractVehicleType(receiptLines);
            result.Color = ValueAfterAnyLabel(receiptLines, [DocumentLabels.Receipt.Color]);

            FlagMissing(result);
            return result;
        }

        /// <summary>
        /// Car or Motorcycle, read off the receipt's own body-type field.
        /// </summary>
        /// <remarks>
        /// LTO prints this as e.g. "Vehicle Type: MC Without Sidecar" — every
        /// motorcycle classification observed starts with "MC". The facility
        /// only has two bay types, so anything else read is treated as a car
        /// rather than trying to enumerate every four-wheeled body type LTO
        /// might print.
        /// </remarks>
        private static string? ExtractVehicleType(List<OcrLineDto> lines)
        {
            var raw = ValueAfterAnyLabel(lines, [DocumentLabels.Receipt.VehicleType]);
            if (string.IsNullOrWhiteSpace(raw))
                return null;

            return raw.TrimStart().StartsWith("MC", StringComparison.OrdinalIgnoreCase)
                ? nameof(VehicleType.Motorcycle)
                : nameof(VehicleType.Car);
        }

        private static List<OcrLineDto> Prepare(OcrPayloadDto? payload)
            => payload is null ? [] : OcrCleanup.Prepare(payload.Lines);

        /// <summary>
        /// Reads the student's details off the registration and assessment form.
        /// </summary>
        /// <remarks>
        /// The header is a table, and it mixes two layouts. "SY &amp; Term:",
        /// "Program:" and "Year Level:" print their value in the cell to the right —
        /// as a separate OCR line, not a continuation of the label's. The student
        /// number and the three name parts are the other way round: the caption sits
        /// underneath the value it describes.
        ///
        /// Both are handled by comparing boxes rather than by reading along a line.
        /// </remarks>
        private static void ExtractSchoolForm(IReadOnlyList<OcrLineDto> lines, ExtractedValuesDto result)
        {
            if (lines.Count == 0)
                return;

            result.StudentNumber = CleanStudentNumber(
                OcrLayout.ValueFor(lines, DocumentLabels.SchoolForm.StudentNumber, captionBelowValue: true));

            // Printed as three separate cells, each read independently — unlike an
            // account's typed name, we genuinely know which part is which here, so
            // they are assembled rather than just gathered.
            var last = OcrLayout.ValueFor(lines, DocumentLabels.SchoolForm.LastName, captionBelowValue: true);
            var first = OcrLayout.ValueFor(lines, DocumentLabels.SchoolForm.FirstName, captionBelowValue: true);
            var middle = OcrLayout.ValueFor(lines, DocumentLabels.SchoolForm.MiddleName, captionBelowValue: true);

            result.StudentName = NameFormat.LastFirstMiddle(last, first, middle);

            result.Semester = ExtractTerm(lines);
            result.Section = ExtractSection(lines);
        }

        /// <summary>
        /// Student numbers are long, digit-only, and start with a zero.
        /// </summary>
        /// <remarks>
        /// The leading zero is real and load-bearing — it must survive as text and
        /// never be normalised away, or two students collide on the unique index.
        /// Lookalike repair is safe here precisely because the field is known to be
        /// all digits.
        /// </remarks>
        private static string? CleanStudentNumber(string? raw)
        {
            if (string.IsNullOrWhiteSpace(raw))
                return null;

            var digits = new string(FuzzyText.RepairDigits(raw).Where(char.IsDigit).ToArray());
            return digits.Length is >= 8 and <= 14 ? digits : null;
        }

        /// <summary>
        /// The school year and term, taken from the financial heading.
        /// </summary>
        /// <remarks>
        /// The header prints this coded — "2627/1T" — while the charges heading
        /// spells it out as "CHARGES for 2026-2027/1st Term". The spelled-out form is
        /// preferred: it is what an administrator has to read when setting the
        /// enrolment end date, and it needs no decoding.
        ///
        /// OCR splits the ordinal, returning "1 st Term", so whitespace is collapsed
        /// before the value is kept.
        /// </remarks>
        private static string? ExtractTerm(IReadOnlyList<OcrLineDto> lines)
        {
            var spelled = OcrLayout.ValueFor(lines, DocumentLabels.SchoolForm.Charges);
            if (!string.IsNullOrWhiteSpace(spelled))
            {
                var collapsed = TermSpacingPattern().Replace(spelled, "$1$2");
                return WhitespacePattern().Replace(collapsed, " ").Trim();
            }

            return OcrLayout.ValueFor(lines, DocumentLabels.SchoolForm.SchoolYearAndTerm);
        }

        /// <summary>
        /// The class section, taken as the value that appears most often in the
        /// subject table.
        /// </summary>
        /// <remarks>
        /// There is no section field on the form. It appears once per enrolled
        /// subject in the "Class No / Sec." column, and OCR damages some of those
        /// copies — the sample returned "BSIT-4B" four times alongside one "BSIT-48"
        /// and one run together with the units as "3,0014385 / BSIT-4B".
        ///
        /// Taking the most frequent reading turns that repetition into an advantage:
        /// the damaged copies disagree with each other, the correct one does not.
        /// </remarks>
        private static string? ExtractSection(IReadOnlyList<OcrLineDto> lines)
        {
            var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

            foreach (var line in lines)
            {
                foreach (Match match in SectionPattern().Matches(line.Text))
                {
                    var section = $"{match.Groups[1].Value.ToUpperInvariant()}-{match.Groups[2].Value.ToUpperInvariant()}";
                    counts[section] = counts.GetValueOrDefault(section) + 1;
                }
            }

            if (counts.Count == 0)
                return null;

            return counts.OrderByDescending(pair => pair.Value).First().Key;
        }

        // "BSIT-4B", "BSIT 4B". The trailing letter is what separates a section from
        // a class number, and rules out mis-reads like "BSIT-48".
        [GeneratedRegex(@"\b([A-Z]{2,6})[\s\-]?(\d[A-Z])\b", RegexOptions.IgnoreCase)]
        private static partial Regex SectionPattern();

        [GeneratedRegex(@"(\d)\s+(st|nd|rd|th)\b", RegexOptions.IgnoreCase)]
        private static partial Regex TermSpacingPattern();

        [GeneratedRegex(@"\s{2,}")]
        private static partial Regex WhitespacePattern();

        /// <summary>
        /// Value following the first label that matches, optionally continuing onto
        /// the next line.
        /// </summary>
        /// <remarks>
        /// Some fields print their value on the same line as the label; a Philippine
        /// driver's licence prints the heading above the value instead. Falling
        /// through to the next line covers the second case without a spatial rule.
        ///
        /// <paramref name="preferNextLine"/> exists for a specific failure this once
        /// had: the licence's name caption is long ("Last Name, First Name, Middle
        /// Name") and reads badly, so the full label often fails to match — at which
        /// point a shorter fallback label in the array (just "Last Name") can still
        /// match, but only because it is sitting *inside* that same garbled caption
        /// line. The "remainder" after it is then more caption noise, not a value,
        /// and was being returned as if it were one. A field known to always print
        /// its value on the line below — never beside the label — should never
        /// accept a same-line remainder at all, whichever label variant matched.
        /// </remarks>
        private static string? ValueAfterAnyLabel(
            List<OcrLineDto> lines,
            string[] labels,
            bool allowNextLine = false,
            bool preferNextLine = false)
        {
            foreach (var label in labels)
            {
                for (var i = 0; i < lines.Count; i++)
                {
                    var after = FuzzyText.IndexAfterLabel(lines[i].Text, label);
                    if (after < 0)
                        continue;

                    if (!preferNextLine)
                    {
                        var remainder = FuzzyText.TrimValue(lines[i].Text[after..]);
                        if (remainder.Length > 1)
                            return remainder;
                    }

                    if (allowNextLine && i + 1 < lines.Count)
                    {
                        var next = FuzzyText.TrimValue(lines[i + 1].Text);
                        if (next.Length > 1)
                            return next;
                    }
                }
            }

            return null;
        }

        /// <summary>
        /// Reads the plate off the Official Receipt.
        /// </summary>
        /// <remarks>
        /// The label and value share one line, so this is a split rather than a
        /// spatial search. Anchoring on the label is what makes it safe: directly
        /// beneath the plate sits a File No that opens with the same digits, and the
        /// CR carries another near-identical number. Any rule that simply hunts for
        /// digits captures the wrong one.
        ///
        /// No plate format is enforced. Motorcycle plates here are digits only while
        /// car plates mix letters and digits, so a pattern like "three letters then
        /// four digits" rejects valid motorcycle plates. The label already
        /// establishes what the value is; its shape does not have to prove it.
        /// </remarks>
        private static string? ExtractPlate(List<OcrLineDto> lines)
        {
            foreach (var line in lines)
            {
                var after = FuzzyText.IndexAfterLabel(line.Text, DocumentLabels.Receipt.PlateNumber);
                if (after < 0)
                    continue;

                var candidate = IdentifierNormalizer.NormalizePlate(
                    FuzzyText.TrimValue(line.Text[after..]));

                if (candidate.Length is >= MinPlateLength and <= MaxPlateLength)
                    return candidate;
            }

            return null;
        }

        /// <summary>
        /// When the registration runs out: read from the receipt if the print
        /// survived, otherwise derived from the plate and the receipt date.
        /// </summary>
        /// <remarks>
        /// The printed expiry sits in a sentence that wraps across several lines —
        /// "This payment is valid until" on one, "01/2026 and due for" on the next —
        /// so the lines are glued into a single stream before searching. Without
        /// that, the anchor and its value are never on the same line.
        ///
        /// Falling back to derivation matters because in testing this paragraph did
        /// not come back at all. A derived answer is recorded as such: it is weaker
        /// evidence than a read one.
        /// </remarks>
        private static DateTime? ExtractRegistrationExpiry(
            List<OcrLineDto> lines,
            string? plate,
            ExtractedValuesDto result)
        {
            var stream = string.Join(' ', lines.Select(l => l.Text));

            var after = FuzzyText.IndexAfterLabel(stream, DocumentLabels.Receipt.ValidUntil);
            if (after >= 0)
            {
                var read = DateExtraction.FindExpiry(stream[after..]);
                if (read is not null)
                    return read;
            }

            var receiptDate = DateExtraction.FindFullDate(
                ValueAfterAnyLabel(lines, DocumentLabels.Receipt.IssueDate));

            var derived = RegistrationRenewal.DeriveExpiry(plate, receiptDate);
            if (derived is not null)
                Flag(result, nameof(result.RegistrationExpiry), FieldFlag.Derived);

            return derived;
        }

        /// <summary>
        /// Marks a field for the user's attention, without ever listing it twice.
        /// </summary>
        private static void Flag(ExtractedValuesDto result, string field, FieldFlag reason)
        {
            if (result.IsFlagged(field))
                return;

            result.FieldsToCheck.Add(new FieldFlagDto
            {
                Field = field,
                Reason = reason.ToString()
            });
        }

        /// <summary>
        /// Names the fields the rules could not fill, so the app can say "we couldn't
        /// read this" rather than presenting an unexplained blank.
        /// </summary>
        private static void FlagMissing(ExtractedValuesDto result)
        {
            void FlagIfEmpty(string? value, string field)
            {
                if (string.IsNullOrWhiteSpace(value))
                    Flag(result, field, FieldFlag.NotFound);
            }

            FlagIfEmpty(result.StudentNumber, nameof(result.StudentNumber));
            FlagIfEmpty(result.StudentName, nameof(result.StudentName));
            FlagIfEmpty(result.Section, nameof(result.Section));
            FlagIfEmpty(result.Semester, nameof(result.Semester));
            FlagIfEmpty(result.LicenseName, nameof(result.LicenseName));
            FlagIfEmpty(result.PlateNumber, nameof(result.PlateNumber));
            FlagIfEmpty(result.Color, nameof(result.Color));

            if (result.LicenseExpiry is null)
                Flag(result, nameof(result.LicenseExpiry), FieldFlag.NotFound);

            // Already flagged as Derived if the plate rule supplied it.
            if (result.RegistrationExpiry is null)
                Flag(result, nameof(result.RegistrationExpiry), FieldFlag.NotFound);
        }
    }
}
