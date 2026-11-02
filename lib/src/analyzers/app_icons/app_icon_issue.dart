import 'package:fcheck/src/analyzers/app_icons/app_icon_issue_type.dart';
import 'package:fcheck/src/analyzers/app_icons/app_icon_platform.dart';

/// A problem with a platform's app icons.
class AppIconIssue {
  /// The platform whose icons have the problem.
  final AppIconPlatform platform;

  /// What kind of problem it is.
  final AppIconIssueType type;

  /// Project-relative path of the file concerned, with `/` separators.
  final String filePath;

  /// What is wrong, for people to read.
  final String message;

  /// Creates an issue.
  const AppIconIssue({
    required this.platform,
    required this.type,
    required this.filePath,
    required this.message,
  });

  /// Converts this issue to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'platform': platform.name,
    'type': type.name,
    'filePath': filePath,
    'message': message,
  };

  /// One report line: platform, path and message.
  String format() => '${platform.label}: $filePath: $message';

  @override
  String toString() => format();
}
