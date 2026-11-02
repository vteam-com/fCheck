/// A Flutter target platform whose app icons are checked, named after its
/// project folder.
enum AppIconPlatform {
  /// `android/`: launcher icons in the `mipmap` densities.
  android('Android'),

  /// `ios/`: the Xcode `AppIcon` asset catalog.
  ios('iOS'),

  /// `macos/`: the Xcode `AppIcon` asset catalog.
  macos('macOS'),

  /// `web/`: the favicon and the web app manifest icons.
  web('Web'),

  /// `windows/`: the `.ico` file the runner's resource script embeds.
  windows('Windows'),

  /// `linux/`: the window icon the GTK runner loads.
  linux('Linux');

  /// Name shown to people.
  final String label;

  const AppIconPlatform(this.label);
}
