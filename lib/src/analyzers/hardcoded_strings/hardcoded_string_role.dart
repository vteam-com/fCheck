/// What a hardcoded string is for, judged from how the code uses it, so a
/// tool can offer the right fix: localize it or make it a constant.
enum HardcodedStringRole {
  /// Text users read, such as a `Text` widget or a `labelText:`; localize
  /// it.
  presentation,

  /// A value the code compares or looks up, such as `.contains(...)`, a
  /// `case`, a `value:` or a Firestore field name; translating it would
  /// break the code, so make it a constant.
  data,

  /// Text shown only inside another message, such as a placeholder of a
  /// localized message; translate the whole message instead.
  fragment,

  /// No use decided the role.
  unknown,
}
