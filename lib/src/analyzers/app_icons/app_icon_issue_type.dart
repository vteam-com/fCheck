/// What is wrong with an app icon.
enum AppIconIssueType {
  /// An icon file the platform expects, or a configuration file listing
  /// the icons, is absent.
  missingFile,

  /// An icon still shows the Flutter logo `flutter create` writes.
  flutterDefault,

  /// A file is not a PNG or ICO image that can be read.
  unreadableImage,

  /// An image is not the size its platform expects.
  wrongSize,

  /// An image that must be square is not.
  notSquare,

  /// An image has an alpha channel the platform rejects, like the iOS
  /// App Store icon.
  hasAlpha,

  /// The platform's configuration does not point at any icon, or lists
  /// an icon slot with no image.
  missingReference,

  /// An icon file or manifest lacks sizes the platform needs.
  missingSizes,

  /// A configuration file that lists the icons cannot be parsed.
  invalidConfiguration,

  /// The icon is loaded from a path relative to the working directory, so
  /// it is not found when the app is launched from elsewhere.
  relativePath,
}
