using AimPark.API.DTOs;

namespace AimPark.API.Interfaces
{
    /// <summary>
    /// Turns what the phone read into the handful of values the system needs.
    /// </summary>
    /// <remarks>
    /// Lives on the server, not the phone, for two reasons: these rules will change
    /// as more real documents are seen, and a rule fix must not require an app store
    /// release; and the server has to redo every comparison for evidence integrity
    /// anyway, so interpreting on the device would be discarded work.
    /// </remarks>
    public interface IDocumentExtractionService
    {
        ExtractedValuesDto Extract(
            OcrPayloadDto? identity,
            OcrPayloadDto? license,
            OcrPayloadDto? receipt,
            OcrPayloadDto? platePhoto);
    }
}
