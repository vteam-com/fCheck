import 'package:fcheck/src/analyzers/app_icons/app_icon_issue.dart';
import 'package:fcheck/src/analyzers/app_icons/app_icon_slot.dart';

/// Every app icon slot of a project's platforms and the problems found.
class AppIconReport {
  /// The slots, platform by platform, in the order their configuration
  /// lists them.
  final List<AppIconSlot> slots;

  /// The problems found.
  final List<AppIconIssue> issues;

  /// Creates a report.
  const AppIconReport({required this.slots, required this.issues});
}
