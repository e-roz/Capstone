using System.Text.Json;
using System.Text.Json.Serialization;
using AimPark.API.DTOs;
using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Reads and writes the outstanding-document list stored on
    /// <c>User.DocumentRetakeJson</c>.
    /// </summary>
    /// <remarks>
    /// The single place that column's shape is known. Everything else works in
    /// terms of <see cref="DocumentRetakeItemDto"/>, so the storage decision
    /// stays reversible: if this ever earns a table, only this file changes.
    /// </remarks>
    public static class DocumentRetakes
    {
        private static readonly JsonSerializerOptions Options = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        /// <summary>
        /// The documents still outstanding, or an empty list when there are
        /// none.
        /// </summary>
        /// <remarks>
        /// Never throws. A column holding something unreadable — hand-edited, or
        /// written by an older shape — reads as "nothing outstanding", which
        /// leaves the applicant in the ordinary queue rather than stuck in a
        /// capture flow that cannot say what it wants.
        /// </remarks>
        public static List<DocumentRetakeItemDto> Read(string? json)
        {
            if (string.IsNullOrWhiteSpace(json))
                return [];

            try
            {
                var items = JsonSerializer.Deserialize<List<DocumentRetakeItemDto>>(json, Options);
                if (items is null)
                    return [];

                // A type this build does not know is dropped rather than passed
                // on: the app matches on these names to decide which capture
                // screens to show, and one it cannot resolve would be a step it
                // can never complete.
                return items
                    .Where(i => Enum.TryParse<DocumentType>(i.Type, ignoreCase: true, out _))
                    .ToList();
            }
            catch (JsonException)
            {
                return [];
            }
        }

        /// <summary>
        /// Serialises the list, or returns null for an empty one so the column
        /// reads as "nothing outstanding" rather than "an empty list of things".
        /// </summary>
        public static string? Write(IReadOnlyCollection<DocumentRetakeItemDto> items)
            => items.Count == 0 ? null : JsonSerializer.Serialize(items, Options);

        /// <summary>
        /// Normalises a reviewer's request: known types only, canonical casing,
        /// trimmed reasons, one entry per type.
        /// </summary>
        /// <returns>False when a type is unknown or a reason is missing.</returns>
        public static bool TryNormalize(
            IReadOnlyCollection<DocumentRetakeItemDto> requested,
            out List<DocumentRetakeItemDto> normalized,
            out string? error)
        {
            normalized = [];
            error = null;

            if (requested.Count == 0)
            {
                error = "Choose at least one document to send back.";
                return false;
            }

            var seen = new HashSet<DocumentType>();

            foreach (var item in requested)
            {
                if (!Enum.TryParse<DocumentType>(item.Type, ignoreCase: true, out var type)
                    || !Enum.IsDefined(type))
                {
                    error = $"Unknown document type '{item.Type}'. Expected one of: "
                        + string.Join(", ", Enum.GetNames<DocumentType>());
                    return false;
                }

                var reason = item.Reason?.Trim();
                if (string.IsNullOrWhiteSpace(reason))
                {
                    error = $"Give a reason for sending back the {type} — without one "
                        + "the applicant will photograph it exactly the same way again.";
                    return false;
                }

                // Last one wins rather than erroring: two entries for the same
                // document is a reviewer changing their mind in the form, not a
                // request worth refusing.
                if (!seen.Add(type))
                    normalized.RemoveAll(n => string.Equals(n.Type, type.ToString(), StringComparison.OrdinalIgnoreCase));

                normalized.Add(new DocumentRetakeItemDto
                {
                    Type = type.ToString(),
                    Reason = reason
                });
            }

            return true;
        }
    }
}
