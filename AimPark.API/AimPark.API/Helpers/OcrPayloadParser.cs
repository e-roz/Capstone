using AimPark.API.DTOs;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Reads an OCR payload out of the multipart form field it arrives in.
    /// </summary>
    public static class OcrPayloadParser
    {
        private static readonly JsonSerializerOptions Options = new()
        {
            PropertyNameCaseInsensitive = true,
            Converters = { new JsonStringEnumConverter() }
        };

        /// <summary>
        /// Returns null when the field is absent or unparseable.
        /// </summary>
        /// <remarks>
        /// Malformed OCR is never an error the applicant sees. A phone that could not
        /// run text recognition, or sent something the server cannot read, still
        /// submits its photos — the values simply arrive empty and the user types
        /// them on the confirmation screen. Rejecting the upload would block a
        /// legitimate applicant over a detail they cannot influence.
        /// </remarks>
        public static OcrPayloadDto? Parse(string? json)
        {
            if (string.IsNullOrWhiteSpace(json))
                return null;

            try
            {
                var payload = JsonSerializer.Deserialize<OcrPayloadDto>(json, Options);

                // Boxes measured against an unknown page size cannot be reasoned
                // about, so treat that as no payload at all.
                if (payload is null || payload.ImageWidth <= 0 || payload.ImageHeight <= 0)
                    return null;

                return payload;
            }
            catch (JsonException)
            {
                return null;
            }
        }
    }
}
