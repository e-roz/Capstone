namespace AimPark.API.DTOs
{
    /// <summary>
    /// Moves an account back to a named registration step.
    /// </summary>
    /// <remarks>
    /// A string holding the enum member name, for the same reason the responses
    /// carry names: nothing registers a <c>JsonStringEnumConverter</c>, so a
    /// property typed as the enum accepts only ordinals. A caller sending the
    /// obvious <c>{"step": "DocumentUpload"}</c> got a deserialiser error, and
    /// one sending <c>{"step": 99}</c> got no error at all — an integer outside
    /// the enum's range binds without complaint and would be written to the
    /// user, leaving a registration step that every switch in the system falls
    /// through. Parsing it by name, in the service, is what makes an invalid
    /// value a clear 400 instead of either.
    /// </remarks>
    public class ResetRegistrationStepDto
    {
        public string Step { get; set; } = string.Empty;
    }
}
