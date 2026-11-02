import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fcheck/fcheck.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// PNG color type of RGB images, without alpha.
const int _rgb = 2;

/// PNG color type of RGBA images.
const int _rgba = 6;

/// The headers of a [size]-pixel-square PNG of [colorType], optionally
/// declaring a transparent color; enough for [AppIconFileInfo.read].
List<int> png(
  int size, {
  int? height,
  int colorType = _rgb,
  bool trns = false,
}) {
  List<int> chunk(String type, List<int> data) => [
    ...(ByteData(4)..setUint32(0, data.length)).buffer.asUint8List(),
    ...ascii.encode(type),
    ...data,
    0, 0, 0, 0, // CRC, not verified
  ];
  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, height ?? size)
    ..setUint8(8, 8)
    ..setUint8(9, colorType);
  return [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk('IHDR', header.buffer.asUint8List()),
    if (trns) ...chunk('tRNS', [0, 0]),
    ...chunk('IDAT', []),
    ...chunk('IEND', []),
  ];
}

/// A real [size]-pixel PNG of one RGB color, decodable to a thumbnail.
List<int> solidPng(int size, List<int> rgb) {
  List<int> chunk(String type, List<int> data) => [
    ...(ByteData(4)..setUint32(0, data.length)).buffer.asUint8List(),
    ...ascii.encode(type),
    ...data,
    0, 0, 0, 0, // CRC, not verified
  ];
  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, _rgb);
  final rows = [
    for (var y = 0; y < size; y++) ...[
      0,
      for (var x = 0; x < size; x++) ...rgb,
    ],
  ];
  return [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk('IHDR', header.buffer.asUint8List()),
    ...chunk('IDAT', ZLibEncoder().convert(rows)),
    ...chunk('IEND', []),
  ];
}

/// Flutter's default 72 px Android launcher icon.
final List<int> flutterDefault72 = File(
  'test/analyze_app_icons/flutter_default_72.png',
).readAsBytesSync();

/// The header and directory of an ICO holding square [sizes].
List<int> ico(List<int> sizes) => [
  0,
  0,
  1,
  0,
  sizes.length,
  0,
  for (final size in sizes) ...[size % 256, size % 256, ...List.filled(14, 0)],
];

void main() {
  late Directory project;

  setUp(() => project = Directory.systemTemp.createTempSync('fcheck_icons_'));
  tearDown(() => project.deleteSync(recursive: true));

  void write(String path, Object content) {
    final file = File(p.join(project.path, path))..createSync(recursive: true);
    if (content is String) {
      file.writeAsStringSync(content);
    } else {
      file.writeAsBytesSync(content as List<int>);
    }
  }

  List<String> check() => [
    for (final issue in const AppIconChecker().check(project))
      '${issue.platform.name} ${issue.type.name} ${issue.filePath}',
  ];

  group('AppIconFileInfo', () {
    test('reads PNG size and alpha', () {
      write('a.png', png(48, colorType: _rgba));
      write('b.png', png(32, height: 16, trns: true));
      write('c.png', png(16));

      final a = AppIconFileInfo.read(File(p.join(project.path, 'a.png')))!;
      final b = AppIconFileInfo.read(File(p.join(project.path, 'b.png')))!;
      final c = AppIconFileInfo.read(File(p.join(project.path, 'c.png')))!;

      expect([a.width, a.height, a.hasAlpha], [48, 48, true]);
      expect([b.width, b.height, b.hasAlpha], [32, 16, true]);
      expect(c.hasAlpha, isFalse);
    });

    test('reads ICO sizes, 0 meaning 256', () {
      write('app.ico', ico([16, 256]));

      final image = AppIconFileInfo.read(
        File(p.join(project.path, 'app.ico')),
      )!;

      expect(image.icoSizes, {16, 256});
      expect(image.width, 256);
    });

    test('rejects other files', () {
      write('text.png', 'not an image');

      expect(
        AppIconFileInfo.read(File(p.join(project.path, 'text.png'))),
        isNull,
      );
      expect(
        AppIconFileInfo.read(File(p.join(project.path, 'none.png'))),
        isNull,
      );
    });
  });

  test('skips platforms without a folder', () {
    expect(check(), isEmpty);
  });

  test('Android: every density at its size', () {
    const res = AppIconChecker.androidResPath;
    write(
      AppIconChecker.androidManifestPath,
      '<manifest><application\n  android:label="a"\n'
      '  android:icon="@mipmap/launcher"></application></manifest>',
    );
    for (final MapEntry(key: folder, value: size)
        in AppIconChecker.androidDensitySizes.entries) {
      if (folder != 'mipmap-mdpi') {
        write('$res/$folder/launcher.png', png(size));
      }
    }
    write('$res/mipmap-hdpi/launcher.png', png(48));

    expect(check(), [
      'android missingFile $res/mipmap-mdpi/launcher.png',
      'android wrongSize $res/mipmap-hdpi/launcher.png',
    ]);
  });

  test('Android: manifest without android:icon', () {
    write(AppIconChecker.androidManifestPath, '<application></application>');

    expect(check(), [
      'android missingReference ${AppIconChecker.androidManifestPath}',
    ]);
  });

  test('iOS: listed images, empty slots and App Store alpha', () {
    final set = AppIconChecker.appleIconSetPath(AppIconPlatform.ios, 'AppIcon');
    write(
      '$set/Contents.json',
      jsonEncode({
        'images': [
          {'size': '20x20', 'scale': '2x', 'filename': 'a.png'},
          {'size': '83.5x83.5', 'scale': '2x', 'filename': 'b.png'},
          {'size': '1024x1024', 'scale': '1x', 'filename': 'store.png'},
          {'size': '29x29', 'scale': '3x'},
        ],
      }),
    );
    write('$set/a.png', png(40));
    write('$set/b.png', png(166));
    write('$set/store.png', png(1024, colorType: _rgba));

    expect(check(), [
      'ios wrongSize $set/b.png',
      'ios hasAlpha $set/store.png',
      'ios missingReference $set/Contents.json',
    ]);
  });

  test('macOS: icon set named in the Xcode project', () {
    write(
      'macos/Runner.xcodeproj/project.pbxproj',
      'ASSETCATALOG_COMPILER_APPICON_NAME = Brand;',
    );

    expect(check(), [
      'macos missingFile macos/Runner/Assets.xcassets/Brand.appiconset/'
          'Contents.json',
    ]);
  });

  test('Web: favicon and manifest sizes', () {
    write(
      'web/index.html',
      '<link rel="icon" type="image/png" href="favicon.png"/>',
    );
    write('web/favicon.png', png(16));
    write(
      'web/manifest.json',
      jsonEncode({
        'icons': [
          {'src': 'icons/Icon-192.png', 'sizes': '192x192'},
        ],
      }),
    );
    write('web/icons/Icon-192.png', png(192));

    expect(check(), ['web missingSizes web/manifest.json']);
  });

  test('Web: invalid manifest', () {
    write('web/index.html', '<html></html>');
    write('web/manifest.json', '{');

    expect(check(), [
      'web missingReference web/index.html',
      'web invalidConfiguration web/manifest.json',
    ]);
  });

  test('Windows: the .ico the resource script names, with every size', () {
    write(
      AppIconChecker.windowsResourceScriptPath,
      r'IDI_APP_ICON ICON "resources\\brand.ico"',
    );
    write('windows/runner/resources/brand.ico', ico([16, 32, 48]));

    expect(check(), [
      'windows missingSizes windows/runner/resources/brand.ico',
    ]);
  });

  test('Linux: no icon, or one relative to the working directory', () {
    const source = 'linux/runner/my_application.cc';
    write(source, 'gtk_window_set_title(window, "app");');
    expect(check(), ['linux missingReference $source']);

    write(
      source,
      'gtk_window_set_icon_from_file(GTK_WINDOW(window),"assets/a.png",NULL);',
    );
    expect(check(), ['linux relativePath $source']);
  });

  test('Linux: the installed icon is checked when the runner uses it', () {
    write(
      'linux/runner/my_application.cc',
      'g_build_filename(dir, "data", "app_icon.png", nullptr);\n'
          'gtk_window_set_icon_from_file(window, icon_path, nullptr);',
    );
    write(AppIconChecker.linuxIconPath, png(128));

    expect(check(), ['linux wrongSize ${AppIconChecker.linuxIconPath}']);
  });

  group('Flutter default icons', () {
    test('thumbnails tell a default icon from a custom one', () {
      write('default.png', flutterDefault72);
      write('custom.png', solidPng(72, [230, 80, 20]));

      final defaultIcon = AppIconThumbnail.of(
        File(p.join(project.path, 'default.png')),
      )!;
      final custom = AppIconThumbnail.of(
        File(p.join(project.path, 'custom.png')),
      )!;

      expect(AppIconThumbnail.fromHex(custom.toHex()).cells, custom.cells);
      expect(custom.cells.take(3), [230, 80, 20]);
      expect(defaultIcon.distanceTo(custom), greaterThan(20));
    });

    test('flags a platform still showing the default icon once', () {
      const res = AppIconChecker.androidResPath;
      write(
        AppIconChecker.androidManifestPath,
        '<application android:icon="@mipmap/ic_launcher">',
      );
      for (final folder in AppIconChecker.androidDensitySizes.keys) {
        write('$res/$folder/ic_launcher.png', flutterDefault72);
      }

      final report = const AppIconChecker().inspect(project);

      expect(
        report.issues.where(
          (issue) => issue.type == AppIconIssueType.flutterDefault,
        ),
        hasLength(1),
      );
      expect(report.slots.every((slot) => slot.isFlutterDefault), isTrue);
      expect(
        const AppIconChecker()
            .inspect(project, detectFlutterDefaults: false)
            .slots
            .any((slot) => slot.isFlutterDefault),
        isFalse,
      );
    });

    test('flags each default size left among the app\'s own', () {
      final set = AppIconChecker.appleIconSetPath(
        AppIconPlatform.macos,
        'AppIcon',
      );
      write(
        '$set/Contents.json',
        jsonEncode({
          'images': [
            {'size': '72x72', 'idiom': 'mac', 'filename': 'old.png'},
            {'size': '128x128', 'idiom': 'mac', 'filename': 'new.png'},
          ],
        }),
      );
      write('$set/old.png', flutterDefault72);
      write('$set/new.png', solidPng(128, [230, 80, 20]));

      expect(check(), ['macos flutterDefault $set/old.png']);
    });
  });

  test('reports every slot as Xcode groups them', () {
    final set = AppIconChecker.appleIconSetPath(AppIconPlatform.ios, 'AppIcon');
    write(
      '$set/Contents.json',
      jsonEncode({
        'images': [
          {
            'size': '20x20',
            'idiom': 'iphone',
            'scale': '2x',
            'filename': 'a.png',
          },
          {'size': '83.5x83.5', 'idiom': 'ipad', 'scale': '2x'},
          {'size': '1024x1024', 'idiom': 'ios-marketing', 'filename': 'b.png'},
        ],
      }),
    );
    write('$set/a.png', png(40));
    write(AppIconChecker.windowsDefaultIconPath, ico([16, 48]));

    final slots = const AppIconChecker().inspect(project).slots;

    expect(
      [
        for (final slot in slots)
          '${slot.group} ${slot.label} ${slot.size} ${slot.isFilled}',
      ],
      [
        'iPhone 20pt @2x 40 true',
        'iPad 83.5pt @2x 167 false',
        'App Store 1024pt @1x 1024 false',
        'app_icon.ico 16 px 16 true',
        'app_icon.ico 32 px 32 false',
        'app_icon.ico 48 px 48 true',
        'app_icon.ico 256 px 256 false',
      ],
    );
    expect(slots[1].filePath, isNull);
  });

  test('iOS single size: one slot per appearance, only Any opaque', () {
    final set = AppIconChecker.appleIconSetPath(AppIconPlatform.ios, 'AppIcon');
    Map<String, Object> entry(String file, [String? appearance]) => {
      'idiom': 'universal',
      'size': '1024x1024',
      'filename': file,
      if (appearance != null)
        'appearances': [
          {'appearance': 'luminosity', 'value': appearance},
        ],
    };
    write(
      '$set/Contents.json',
      jsonEncode({
        'images': [
          entry('any.png'),
          entry('dark.png', 'dark'),
          entry('tinted.png', 'tinted'),
        ],
      }),
    );
    write('$set/any.png', png(1024));
    write('$set/dark.png', png(1024, colorType: _rgba));
    write('$set/tinted.png', png(1024, colorType: _rgba));

    final report = const AppIconChecker().inspect(project);

    expect(
      [for (final slot in report.slots) slot.label],
      ['1024pt Any', '1024pt Dark', '1024pt Tinted'],
    );
    expect(report.slots.first.group, 'Single size');
    expect(report.issues, isEmpty);
  });

  test('AnalyzeFolder reports app icon issues in its JSON', () {
    write('pubspec.yaml', 'name: app');
    write(AppIconChecker.androidManifestPath, '<application></application>');

    final json = AnalyzeFolder(project).analyze().toJson();

    expect(json['appIconIssues'], [
      {
        'platform': 'android',
        'type': 'missingReference',
        'filePath': AppIconChecker.androidManifestPath,
        'message':
            'The <application> element has no android:icon; Android shows '
            'a default icon',
      },
    ]);
  });
}
