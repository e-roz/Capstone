namespace AimPark.API.DTOs
{
    public class GoogleSignInDto
    {
        public string IdToken { get; set; } = string.Empty;

        /// <summary>
        /// Which button the user pressed: <c>login</c> or <c>signup</c>.
        /// </summary>
        /// <remarks>
        /// The two differ in exactly one rule — a log-in must never create an
        /// account — so they share this endpoint rather than splitting it, and
        /// everything after that first decision is identical.
        ///
        /// It matters because the app had one Google button, on the sign-in
        /// screen, running the sign-up path: pressing it with an address that
        /// had no account silently created one, and pressing it with an address
        /// that did produced a message about the account already existing. The
        /// button could create an account but never open one.
        ///
        /// Null is read as <c>signup</c>, which is what this endpoint did before
        /// the field existed. That keeps an older build of the app working
        /// against a newer server rather than having every Google press fail.
        /// </remarks>
        public string? Intent { get; set; }
    }
}
