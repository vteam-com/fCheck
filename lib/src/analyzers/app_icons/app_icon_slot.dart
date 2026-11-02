import 'package:fcheck/src/analyzers/app_icons/app_icon_file_info.dart';
import 'package:fcheck/src/analyzers/app_icons/app_icon_platform.dart';

/// One place a platform shows its app icon, such as the iPhone 20pt @2x
/// slot of an asset catalog: what it expects and which file fills it.
class AppIconSlot {
  /// The platform showing the icon.
  final AppIconPlatform platform;

  /// What the slot is for, grouping slots as Xcode does: `iPhone`, `iPad`,
  /// `App Store`, `Mac`, `Launcher`, `Browser`…
  final String group;

  /// The slot within its [group], such as `20pt @2x` or `xxhdpi`.
  final String label;

  /// Project-relative path of the file filling the slot, with `/`
  /// separators; null when the slot lists no file.
  final String? filePath;

  /// Width and height the slot expects, in pixels; null when any square
  /// size will do.
  final int? size;

  /// The file's size and format; null when it is missing or unreadable.
  final AppIconFileInfo? file;

  /// Whether the file still shows Flutter's default icon.
  final bool isFlutterDefault;

  /// Creates a slot.
  const AppIconSlot({
    required this.platform,
    required this.group,
    required this.label,
    required this.filePath,
    required this.size,
    required this.file,
    this.isFlutterDefault = false,
  });

  /// Whether an image fills the slot: its file can be read and, for an
  /// image embedded in an ICO, holds that size.
  bool get isFilled {
    final file = this.file;
    if (file == null) return false;
    if (file.icoSizes.isEmpty || size == null) return true;
    return file.icoSizes.contains(size);
  }

  /// This slot flagged as still showing Flutter's default icon.
  AppIconSlot asFlutterDefault() => AppIconSlot(
    platform: platform,
    group: group,
    label: label,
    filePath: filePath,
    size: size,
    file: file,
    isFlutterDefault: true,
  );
}
