namespace AimPark.API.Helpers
{
    public class ValidationHelper
    {
        public static bool HasEmptyFields(params string?[] fields)
        {
            return fields.Any(string.IsNullOrWhiteSpace);
        }
    }
}
