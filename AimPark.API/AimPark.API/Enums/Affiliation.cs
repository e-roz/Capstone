namespace AimPark.API.Enums
{
    /// <summary>
    /// How a person is attached to the school.
    /// </summary>
    /// <remarks>
    /// Deliberately separate from <see cref="UserRole"/>. Role answers "what may you
    /// do" — and a student and a faculty member answer that identically, so folding
    /// them into the role enum would force every permission check to list both.
    ///
    /// This answers "who are you to the school", which decides which documents the
    /// pre-screening rules expect and whether access expires with a semester.
    /// It is also what makes a null StudentNumber readable: without it, an empty
    /// student number cannot be told apart from a student whose RAF would not read.
    /// </remarks>
    public enum Affiliation
    {
        Student,
        Faculty,
        Staff
    }
}
