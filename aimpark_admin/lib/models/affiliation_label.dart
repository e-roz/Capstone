/// The server's affiliation as the panel shows it.
///
/// Faculty and staff became one sign-up option, "Faculty / Staff", because they
/// send the same documents and are checked the same way. Accounts made before
/// that still carry "Staff", so both values read the same here. Only "Student"
/// is ever compared against, so the label is safe to use as the value.
String affiliationLabel(String? wire) => switch (wire) {
  'Faculty' || 'Staff' => 'Faculty / Staff',
  null || '' => 'Student',
  _ => wire,
};
