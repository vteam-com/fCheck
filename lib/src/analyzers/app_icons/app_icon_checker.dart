import 'dart:convert';
import 'dart:io';

import 'package:fcheck/src/analyzers/app_icons/app_icon_file_info.dart';
import 'package:fcheck/src/analyzers/app_icons/app_icon_flutter_defaults.dart';
import 'package:fcheck/src/analyzers/app_icons/app_icon_issue.dart';
import 'package:fcheck/src/analyzers/app_icons/app_icon_issue_type.dart';
import 'package:fcheck/src/analyzers/app_icons/app_icon_platform.dart';
import 'package:fcheck/src/analyzers/app_icons/app_icon_report.dart';
import 'package:fcheck/src/analyzers/app_icons/app_icon_slot.dart';
import 'package:fcheck/src/analyzers/app_icons/app_icon_thumbnail.dart';
import 'package:path/path.dart' as p;

/// Checks the app icons of every platform folder a Flutter project has:
/// that each icon its configuration lists exists, can be read and has the
/// size the platform expects.
///
/// The paths and sizes it expects are public so tools can generate icons
/// that pass it.
class AppIconChecker {
  /// Creates a stateless checker.
  const AppIconChecker();

  /// Android launcher icon size in pixels per `mipmap` density folder.
  static const Map<String, int> androidDensitySizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  /// Project-relative Android resources folder.
  static const String androidResPath = 'android/app/src/main/res';

  /// Project-relative Android manifest, whose `android:icon` names the icon.
  static const String androidManifestPath =
      'android/app/src/main/AndroidManifest.xml';

  /// Icon resource name of new Flutter projects.
  static const String androidDefaultIconName = 'ic_launcher';

  /// Asset catalog icon set of new Flutter projects on iOS and macOS.
  static const String appleDefaultIconSetName = 'AppIcon';

  /// Size of the iOS App Store icon, which must have no alpha channel.
  static const int appStoreIconSize = 1024;

  /// Project-relative web app manifest.
  static const String webManifestPath = 'web/manifest.json';

  /// Project-relative web page declaring the favicon.
  static const String webIndexPath = 'web/index.html';

  /// Icon sizes browsers need in the web app manifest to install the app.
  static const Set<int> webRequiredSizes = {192, 512};

  /// Project-relative Windows resource script embedding the icon.
  static const String windowsResourceScriptPath = 'windows/runner/Runner.rc';

  /// Folder the Windows resource script's paths are relative to.
  static const String windowsRunnerPath = 'windows/runner';

  /// Project-relative Windows icon of new Flutter projects.
  static const String windowsDefaultIconPath =
      'windows/runner/resources/app_icon.ico';

  /// Sizes a Windows `.ico` needs for the taskbar, title bar, Explorer and
  /// the Start menu.
  static const Set<int> windowsRequiredSizes = {16, 32, 48, 256};

  /// Project-relative GTK runner sources, newest template first.
  static const List<String> linuxApplicationPaths = [
    'linux/runner/my_application.cc',
    'linux/my_application.cc',
  ];

  /// Project-relative Linux window icon, installed next to the executable.
  static const String linuxIconPath = 'linux/runner/resources/app_icon.png';

  /// Smallest Linux window icon that stays sharp in docks and switchers.
  static const int linuxMinIconSize = 256;

  /// The project-relative icon set folder of [platform] (iOS or macOS)
  /// named [name].
  static String appleIconSetPath(AppIconPlatform platform, String name) =>
      '${platform.name}/Runner/Assets.xcassets/$name.appiconset';

  /// Names the icon set in an Xcode project file.
  static final RegExp _appleIconSetSetting = RegExp(
    r'ASSETCATALOG_COMPILER_APPICON_NAME\s*=\s*"?([\w-]+)"?;',
  );

  /// The `android:icon` of the manifest's `<application>` element,
  /// capturing the resource type and name.
  static final RegExp _androidIcon = RegExp(
    r'<application\b[^>]*?android:icon="@(mipmap|drawable)/([\w.]+)"',
  );

  /// A `<link>` declaring the favicon.
  static final RegExp _faviconLink = RegExp(
    r'''<link\b[^>]*\brel=["'](?:shortcut )?icon["'][^>]*>''',
  );

  /// The `href` of a `<link>`, capturing its value.
  static final RegExp _href = RegExp(r'''\bhref=["']([^"']+)["']''');

  /// The icon a Windows resource script embeds, capturing its path.
  static final RegExp _windowsIcon = RegExp(r'\bICON\s+"([^"]+)"');

  /// A GTK call loading the window icon from a literal file path,
  /// capturing the path.
  static final RegExp _linuxIconFromLiteral = RegExp(
    r'gtk_window_set(?:_default)?_icon_from_file\s*\((?:[^,"]*,)?\s*"([^"]+)"',
  );

  /// Any GTK call setting the window icon.
  static final RegExp _linuxIconCall = RegExp(
    r'gtk_window_set(?:_default)?_icon',
  );

  /// URL schemes of favicons that are not project files.
  static final RegExp _externalUrl = RegExp(r'^(?:[a-z]+:|//)');

  /// Parts of a `WxH` size value.
  static const int _sizeParts = 2;

  /// Group of [_androidIcon] capturing the resource type.
  static const int _androidIconTypeGroup = 1;

  /// Group of [_androidIcon] capturing the resource name.
  static const int _androidIconNameGroup = 2;

  /// The project-relative icon set folder of [platform] (iOS or macOS) in
  /// the project at [projectPath]: the set its Xcode project names, or
  /// [appleDefaultIconSetName].
  static String appleIconSetPathIn(
    String projectPath,
    AppIconPlatform platform,
  ) {
    final projectFile = _readIn(
      projectPath,
      '${platform.name}/Runner.xcodeproj/project.pbxproj',
    );
    final name =
        (projectFile == null
            ? null
            : _appleIconSetSetting.firstMatch(projectFile)?.group(1)) ??
        appleDefaultIconSetName;
    return appleIconSetPath(platform, name);
  }

  /// The `android:icon` of [manifest]'s `<application>` element: its
  /// resource type (`mipmap` or `drawable`) and name; null when absent.
  static ({String type, String name})? androidIcon(String manifest) {
    final match = _androidIcon.firstMatch(manifest);
    if (match == null) return null;
    return (
      type: match.group(_androidIconTypeGroup)!,
      name: match.group(_androidIconNameGroup)!,
    );
  }

  /// The `href` of the favicon `<link>` in [indexHtml]; null when there
  /// is none.
  static String? faviconHref(String indexHtml) {
    final link = _faviconLink.firstMatch(indexHtml);
    return link == null ? null : _href.firstMatch(link.group(0)!)?.group(1);
  }

  /// Project-relative path of a web page's [href]; null when it is an
  /// external URL.
  static String? webPath(String href) {
    if (_externalUrl.hasMatch(href)) return null;
    final path = href.split(RegExp('[?#]')).first;
    return p.posix.normalize('web/${path.replaceFirst(RegExp('^/+'), '')}');
  }

  /// The project-relative `.ico` the Windows resource script of the
  /// project at [projectPath] embeds, or [windowsDefaultIconPath].
  static String windowsIconPathIn(String projectPath) {
    final script = _readIn(projectPath, windowsResourceScriptPath);
    final declared = script == null
        ? null
        : _windowsIcon.firstMatch(script)?.group(1);
    if (declared == null) return windowsDefaultIconPath;
    return p.posix.normalize(
      '$windowsRunnerPath/'
      '${declared.replaceAll(r'\\', '/').replaceAll(r'\', '/')}',
    );
  }

  /// The project-relative GTK runner source of the project at
  /// [projectPath]; null when it has none.
  static String? linuxApplicationPathIn(String projectPath) =>
      linuxApplicationPaths
          .where((path) => File(p.join(projectPath, path)).existsSync())
          .firstOrNull;

  /// The side of a square `WxH` [size] value, such as `83.5x83.5` in an
  /// asset catalog or `192x192` in a web manifest; null when it is not one.
  static double? squareSize(Object? size) {
    final parts = '$size'.split('x');
    if (parts.length != _sizeParts || parts.first != parts.last) return null;
    return double.tryParse(parts.first);
  }

  /// The scale of an asset catalog [image] entry, `2` for `"2x"`; 1 when
  /// it has none.
  static int appleImageScale(Map<Object?, Object?> image) =>
      int.tryParse('${image['scale'] ?? '1x'}'.replaceAll('x', '')) ?? 1;

  /// The pixel size of a square asset catalog [image] entry: its point
  /// size times its scale; null when it is not square.
  static int? applePixelSize(Map<Object?, Object?> image) {
    final points = squareSize(image['size']);
    return points == null ? null : (points * appleImageScale(image)).round();
  }

  /// The text of [path] relative to [projectPath], or null when it can't
  /// be read.
  static String? _readIn(String projectPath, String path) {
    try {
      return File(p.join(projectPath, path)).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  /// The icon problems of the project in [projectDir], platform by
  /// platform; platforms without a folder are skipped.
  List<AppIconIssue> check(Directory projectDir) => inspect(projectDir).issues;

  /// Every icon slot of the project in [projectDir] and its problems,
  /// platform by platform; platforms without a folder are skipped.
  ///
  /// Telling icons still showing Flutter's default artwork decodes them;
  /// skip it with [detectFlutterDefaults] false when only the slots matter.
  AppIconReport inspect(
    Directory projectDir, {
    bool detectFlutterDefaults = true,
  }) {
    final slots = <AppIconSlot>[];
    final issues = <AppIconIssue>[];
    for (final platform in AppIconPlatform.values) {
      if (!Directory(p.join(projectDir.path, platform.name)).existsSync()) {
        continue;
      }
      final check = _PlatformCheck(projectDir.path, platform)
        ..run(detectFlutterDefaults: detectFlutterDefaults);
      slots.addAll(check.slots);
      issues.addAll(check.issues);
    }
    return AppIconReport(slots: slots, issues: issues);
  }

  /// Slot groups of asset catalog idioms, named as Xcode shows them.
  static const Map<String, String> _appleIdiomGroups = {
    'iphone': 'iPhone',
    'ipad': 'iPad',
    'ios-marketing': 'App Store',
    'mac': 'Mac',
    'universal': 'Single size',
  };
}

/// The checks of one platform, collecting their issues.
class _PlatformCheck {
  _PlatformCheck(this.root, this.platform);

  /// Project root path.
  final String root;

  /// The platform checked.
  final AppIconPlatform platform;

  /// The problems found.
  final List<AppIconIssue> issues = [];

  /// The platform's icon slots, in the order its configuration lists them.
  final List<AppIconSlot> slots = [];

  /// Project-relative paths of icon files already checked.
  final Set<String> _checkedImages = {};

  /// Runs the platform's checks, filling [slots] and [issues]; Flutter's
  /// default icons are told only when [detectFlutterDefaults].
  void run({required bool detectFlutterDefaults}) {
    switch (platform) {
      case AppIconPlatform.android:
        _checkAndroid();
      case AppIconPlatform.ios || AppIconPlatform.macos:
        _checkApple();
      case AppIconPlatform.web:
        _checkWeb();
      case AppIconPlatform.windows:
        _checkWindows();
      case AppIconPlatform.linux:
        _checkLinux();
    }
    if (detectFlutterDefaults) _checkFlutterDefaults();
  }

  /// Flags the icons still showing Flutter's default artwork: the
  /// platform's largest icon when they all do, else each one that does.
  void _checkFlutterDefaults() {
    final isDefault = <String, bool>{};
    final widths = <String, int>{};
    for (final slot in slots) {
      final path = slot.filePath;
      final file = slot.file;
      if (path == null || file == null || isDefault.containsKey(path)) {
        continue;
      }
      if (file.width < AppIconFlutterDefaults.minSize) continue;
      final thumbnail = AppIconThumbnail.of(File(p.join(root, path)));
      isDefault[path] =
          thumbnail != null && AppIconFlutterDefaults.matches(thumbnail);
      widths[path] = file.width;
    }
    final defaults = [
      for (final MapEntry(key: path, value: matches) in isDefault.entries)
        if (matches) path,
    ];
    if (defaults.isEmpty) return;
    final allDefault = defaults.length == isDefault.length;
    for (var i = 0; i < slots.length; i++) {
      if (allDefault || defaults.contains(slots[i].filePath)) {
        slots[i] = slots[i].asFlutterDefault();
      }
    }
    if (allDefault) {
      _add(
        AppIconIssueType.flutterDefault,
        defaults.reduce((a, b) => widths[a]! >= widths[b]! ? a : b),
        "Still Flutter's default icon; replace it with the app's own",
      );
      return;
    }
    for (final path in defaults) {
      _add(
        AppIconIssueType.flutterDefault,
        path,
        "Still Flutter's default icon, while other sizes show the app's own",
      );
    }
  }

  /// Checks the manifest's `android:icon` and the icon in each density.
  void _checkAndroid() {
    final manifest = _read(AppIconChecker.androidManifestPath);
    if (manifest == null) {
      _add(
        AppIconIssueType.missingFile,
        AppIconChecker.androidManifestPath,
        'Missing the Android manifest',
      );
      return;
    }
    final icon = AppIconChecker.androidIcon(manifest);
    if (icon == null) {
      _add(
        AppIconIssueType.missingReference,
        AppIconChecker.androidManifestPath,
        'The <application> element has no android:icon; Android shows a '
        'default icon',
      );
      return;
    }
    final name = icon.name;
    if (icon.type == 'drawable') {
      final drawable = '${AppIconChecker.androidResPath}/drawable/$name';
      if (!_exists('$drawable.png') && !_exists('$drawable.xml')) {
        _add(
          AppIconIssueType.missingFile,
          '$drawable.png',
          'Missing the icon android:icon names',
        );
      }
      return;
    }
    for (final MapEntry(key: folder, value: size)
        in AppIconChecker.androidDensitySizes.entries) {
      _checkImage(
        '${AppIconChecker.androidResPath}/$folder/$name.png',
        group: 'Launcher',
        label: folder.replaceFirst('mipmap-', ''),
        size: size,
      );
    }
  }

  /// Checks every image the platform's asset catalog icon set lists,
  /// the set being the one the Xcode project names.
  void _checkApple() {
    final setPath = AppIconChecker.appleIconSetPathIn(root, platform);
    final name = p.basenameWithoutExtension(setPath);
    final contentsPath = '$setPath/Contents.json';
    final contents = _read(contentsPath);
    if (contents == null) {
      _add(
        AppIconIssueType.missingFile,
        contentsPath,
        'Missing the $name icon set of the asset catalog',
      );
      return;
    }
    final images = _jsonList(contentsPath, contents, 'images');
    if (images == null) return;
    for (final image in images.whereType<Map>()) {
      final pixels = AppIconChecker.applePixelSize(image);
      if (pixels == null) continue;
      final scale = AppIconChecker.appleImageScale(image);
      final idiom = '${image['idiom']}';
      final group = AppIconChecker._appleIdiomGroups[idiom] ?? idiom;
      final appearance = _appleAppearance(image);
      final points = '${image['size']}'.split('x').first;
      // Single-size icon sets vary by appearance, the others by size
      final label = idiom == 'universal'
          ? '${points}pt ${appearance ?? 'Any'}'
          : '${points}pt @${scale}x${appearance == null ? '' : ' $appearance'}';
      final filename = image['filename'];
      if (filename is! String) {
        slots.add(
          AppIconSlot(
            platform: platform,
            group: group,
            label: label,
            filePath: null,
            size: pixels,
            file: null,
          ),
        );
        _add(
          AppIconIssueType.missingReference,
          contentsPath,
          'No image for the ${image['size']} @${scale}x slot '
          '($pixels×$pixels px)',
        );
        continue;
      }
      _checkImage(
        '$setPath/$filename',
        group: group,
        label: label,
        size: pixels,
        // Dark and tinted icons may be transparent
        opaque:
            platform == AppIconPlatform.ios &&
            appearance == null &&
            pixels == AppIconChecker.appStoreIconSize,
      );
    }
  }

  /// Checks the favicon `index.html` links and the web app manifest's
  /// icons, which must include the sizes browsers install apps with.
  void _checkWeb() {
    final index = _read(AppIconChecker.webIndexPath);
    if (index != null) {
      final href = AppIconChecker.faviconHref(index);
      if (href == null) {
        _add(
          AppIconIssueType.missingReference,
          AppIconChecker.webIndexPath,
          'No <link rel="icon">; browsers show a default icon',
        );
      } else if (AppIconChecker.webPath(href) case final path?) {
        _checkImage(path, group: 'Browser', label: 'Favicon');
      }
    }

    final manifest = _read(AppIconChecker.webManifestPath);
    if (manifest == null) {
      _add(
        AppIconIssueType.missingFile,
        AppIconChecker.webManifestPath,
        'Missing the web app manifest listing the app icons',
      );
      return;
    }
    final icons = _jsonList(AppIconChecker.webManifestPath, manifest, 'icons');
    if (icons == null) return;
    final sizes = <int>{};
    for (final icon in icons.whereType<Map>()) {
      final src = icon['src'];
      if (src is! String) continue;
      final size = AppIconChecker.squareSize(icon['sizes'])?.round();
      if (size != null) sizes.add(size);
      final maskable = '${icon['purpose'] ?? ''}'.contains('maskable');
      if (AppIconChecker.webPath(src) case final path?) {
        _checkImage(
          path,
          group: 'Web app',
          label:
              '${size == null ? p.posix.basename(path) : '$size px'}'
              '${maskable ? ' maskable' : ''}',
          size: size,
        );
      }
    }
    final missing = AppIconChecker.webRequiredSizes.difference(sizes);
    if (missing.isNotEmpty) {
      _add(
        AppIconIssueType.missingSizes,
        AppIconChecker.webManifestPath,
        'Lists no ${_sizeList(missing)} icons; browsers need '
        '${_sizeList(AppIconChecker.webRequiredSizes)} icons to install '
        'the app',
      );
    }
  }

  /// Checks the `.ico` the resource script embeds holds every size
  /// Windows shows.
  void _checkWindows() {
    final iconPath = AppIconChecker.windowsIconPathIn(root);
    final image = _checkImage(
      iconPath,
      group: p.posix.basename(iconPath),
      label: 'Icon file',
      isSlot: false,
    );
    for (final size in {
      ...AppIconChecker.windowsRequiredSizes,
      ...?image?.icoSizes,
    }.toList()..sort()) {
      slots.add(
        AppIconSlot(
          platform: platform,
          group: p.posix.basename(iconPath),
          label: '$size px',
          filePath: iconPath,
          size: size,
          file: image,
        ),
      );
    }
    if (image == null) return;
    if (image.icoSizes.isEmpty) {
      _add(
        AppIconIssueType.unreadableImage,
        iconPath,
        'Not an ICO file; Windows embeds icons in the .ico format',
      );
      return;
    }
    final missing = {
      for (final slot in slots)
        if (!slot.isFilled &&
            AppIconChecker.windowsRequiredSizes.contains(slot.size))
          slot.size!,
    };
    if (missing.isNotEmpty) {
      _add(
        AppIconIssueType.missingSizes,
        iconPath,
        'Holds no ${_sizeList(missing)} image; Windows scales another one, '
        'which looks blurry',
      );
    }
  }

  /// Checks the GTK runner sets a window icon from a path that holds
  /// wherever the app is launched, and the size of the installed icon.
  void _checkLinux() {
    final sourcePath = AppIconChecker.linuxApplicationPathIn(root);
    if (sourcePath == null) return;
    final source = _read(sourcePath)!;
    final literal = AppIconChecker._linuxIconFromLiteral.firstMatch(source);
    if (literal != null && !p.isAbsolute(literal.group(1)!)) {
      _add(
        AppIconIssueType.relativePath,
        sourcePath,
        'Loads "${literal.group(1)}" relative to the working directory; the '
        'window has no icon when the app is launched from elsewhere',
      );
    } else if (!AppIconChecker._linuxIconCall.hasMatch(source)) {
      _add(
        AppIconIssueType.missingReference,
        sourcePath,
        'The GTK window sets no icon; Linux shows a default one',
      );
    }

    final iconPath = AppIconChecker.linuxIconPath;
    if (!_exists(iconPath) && !source.contains(p.basename(iconPath))) return;
    final image = _checkImage(iconPath, group: 'Window', label: 'Window icon');
    if (image != null &&
        image.width == image.height &&
        image.width < AppIconChecker.linuxMinIconSize) {
      _add(
        AppIconIssueType.wrongSize,
        iconPath,
        'Is ${image.width}×${image.height} px; at least '
        '${AppIconChecker.linuxMinIconSize}×'
        '${AppIconChecker.linuxMinIconSize} px stays sharp',
      );
    }
  }

  /// Records the slot [label] of [group] filled by project-relative [path]
  /// unless not [isSlot], then checks the file, once: that it exists, can
  /// be read, is [size] pixels square (or just square when null), and
  /// when [opaque], has no alpha channel. Returns it when it can be read.
  AppIconFileInfo? _checkImage(
    String path, {
    required String group,
    required String label,
    int? size,
    bool opaque = false,
    bool isSlot = true,
  }) {
    final file = File(p.join(root, path));
    if (isSlot) {
      slots.add(
        AppIconSlot(
          platform: platform,
          group: group,
          label: label,
          filePath: path,
          size: size,
          file: AppIconFileInfo.read(file),
        ),
      );
    }
    if (!_checkedImages.add(path)) return null;
    if (!file.existsSync()) {
      _add(
        AppIconIssueType.missingFile,
        path,
        size == null ? 'Missing icon' : 'Missing $size×$size px icon',
      );
      return null;
    }
    final image = AppIconFileInfo.read(file);
    if (image == null) {
      _add(
        AppIconIssueType.unreadableImage,
        path,
        'Not a PNG or ICO image that can be read',
      );
      return null;
    }
    final actual = '${image.width}×${image.height} px';
    if (size != null && (image.width != size || image.height != size)) {
      _add(
        AppIconIssueType.wrongSize,
        path,
        'Is $actual; expected $size×$size px',
      );
    } else if (size == null && image.width != image.height) {
      _add(AppIconIssueType.notSquare, path, 'Is $actual; icons are square');
    }
    if (opaque && image.hasAlpha) {
      _add(
        AppIconIssueType.hasAlpha,
        path,
        'Has an alpha channel; the App Store rejects transparent app icons',
      );
    }
    return image;
  }

  /// The appearance an asset catalog [image] entry is for, capitalized as
  /// Xcode shows it (`Dark`, `Tinted`); null for the default appearance.
  static String? _appleAppearance(Map<Object?, Object?> image) {
    final appearances = image['appearances'];
    if (appearances is! List) return null;
    for (final appearance in appearances.whereType<Map>()) {
      final value = '${appearance['value'] ?? ''}';
      if (value.isEmpty) continue;
      return '${value[0].toUpperCase()}${value.substring(1)}';
    }
    return null;
  }

  /// The [key] list of JSON [content] read from [path]; null, after
  /// reporting it, when the content is not JSON or has no such list.
  List<Object?>? _jsonList(String path, String content, String key) {
    Object? json;
    try {
      json = jsonDecode(content);
    } on FormatException {
      json = null;
    }
    final list = json is Map ? json[key] : null;
    if (list is List) return list;
    _add(
      AppIconIssueType.invalidConfiguration,
      path,
      json == null ? 'Is not valid JSON' : 'Has no "$key" list',
    );
    return null;
  }

  /// [sizes] in increasing order, as `16, 32 px`.
  static String _sizeList(Set<int> sizes) =>
      '${(sizes.toList()..sort()).join(', ')} px';

  /// Whether project-relative [path] is a file.
  bool _exists(String path) => File(p.join(root, path)).existsSync();

  /// The text of project-relative [path], or null when it can't be read.
  String? _read(String path) => AppIconChecker._readIn(root, path);

  /// Records an issue of [type] with project-relative [path].
  void _add(AppIconIssueType type, String path, String message) {
    issues.add(
      AppIconIssue(
        platform: platform,
        type: type,
        filePath: path,
        message: message,
      ),
    );
  }
}
