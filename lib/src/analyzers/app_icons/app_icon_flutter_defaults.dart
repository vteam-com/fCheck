import 'package:fcheck/src/analyzers/app_icons/app_icon_thumbnail.dart';

/// The icons `flutter create` has written over the years, to tell an app
/// that still shows them.
///
/// One thumbnail per distinct artwork among the 64 px and larger default
/// icons of every `flutter_template_images` release and, before it, of
/// the Flutter repository's templates; the other sizes of an artwork are
/// within [maxDistance] of it.
class AppIconFlutterDefaults {
  /// Thumbnails of the default artworks, as [AppIconThumbnail.toHex].
  static const List<String> _thumbnails = [
    'fffffffefefefefefefefefefefefefefefefefefefffffffefefefefefeffff'
        'fffefefed4f0fde8f7fefefefefefefefcfcfcfffffffefefea5dffb83d4f9f6'
        'fbfefffffffcfcfcfcfcfcfefefea5dffb84d4f9dff3fdf0f9fefffffffcfcfc'
        'fcfcfcfefefeb8e6fb9fddfa72cef8edf9fefffffffcfcfcfbfbfbfffffffefe'
        'fe84ccf1468abcf3f6fafffffffcfcfcfcfcfcfbfbfbfffffffefefeb7cfe2da'
        'e6f0fbfbfbfcfcfcfffffff9f9f9f6f6f6f6f6f6f6f6f6f6f6f6f9f9f9ffffff',
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
        'ffe8f7fe74cff999dcfafdfefeffffffffffffffffffe8f7fe68cbf883d5f9f9'
        'fdfeffffffffffffffffffe8f7fe68cbf883d5f9daf2fdd6f1fdfdfefeffffff'
        'ffffffebf8fe97dbfaaae2fb54c5f7bbe8fcfffffffffffffffffffffffff8fc'
        'fe47bff53e95c9f4f7faffffffffffffffffffffffffffffffe3edf43b7cb06b'
        '9cc4fdfdfeffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
        'fffdfcfff9f3fffffffffffffffffffffffffffffffffaf5ffcc96ffc383ffcd'
        'c1ffc3b9fff7f5fffaf6ffcb95ffbd94ffb78affbd85ff9280ff9887ffe9e6ff'
        'f1edffb38affbc85ffa49dffa48affb7acfff3f1ffffffffd4cdff907eff9c8c'
        'ffc2baffe5e7fffffffffffffffffffffcfcfff3f1fffefeffffffffffffffff'
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    'fffffffffffffffffffafdfe8ed9fa5ec8f88cd8fafafdfefffffffffffffafd'
        'fe8fd9fa5ec8f88cd8fafafdfefffffffffffffafdfe90d9fa5fc8f88dd8fafa'
        'fdfefffffffffffffafdfe8fd9fa5fc8f88dd8fae7f6fdccedfcccedfcfafdfe'
        'fafdfe8ed8fa8dd8faddf3fd6bcdf85bc7f8b9e7fbfffffffffffffafdfee1f4'
        'fd47c0f63dbcf6b3e3f9fffffffffffffffffffffffff9fdfe6ecdf81a80c150'
        '8bbaf8fafcfffffffffffffffffffffffff8fbfc518cba065a9d4f8ab9f8fafc',
    'fffffffefefefefefefefefefefefefefefefefefefefefefdfdfdfdfdfdfdfd'
        'fdfdfdfdfdfdfdfdfdfdfdfdfdfbfbfbfdfdfdfdfdfdfdfdfde4c9fdd9b3fde0'
        'dbfdf3f2fdfbfbfbfdfdfdead7fdcea3fdb58bfdb785fd8f7efdc0b7fdfbfbfb'
        'fdfdfdc9b9fdaf84fda596fdaa98fdd8d2fdfcfcfdfbfbfbfdfdfdc3b9fdb8ae'
        'fddad4fdf6f6fdfdfdfdfdfdfdfbfbfbfcfcfcfcfcfcfcfcfcfcfcfcfcfcfcfc'
        'fcfcfcfcfcfafafafdfdfdf2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2fdfdfd',
    'fffffffffffffffffffefeffbce8fca3dffbd7f1fdfffffffffffffffffffefe'
        'ffaae2fb54c5f88fd9fafcfefefffffffffffffefeffaae2fb54c5f88fd9fafc'
        'fefeffffffffffffffffffabe2fb54c5f88fd9fadbf2fdc8ecfce1f4fdffffff'
        'ffffffb9e7fc90d9fabfe9fc57c6f874d0f9f2fafeffffffffffffffffffe6f6'
        'fe30b8f634ace6e9f4fbffffffffffffffffffffffffffffffa6d9f3055a9947'
        '85b6f6f9fbffffffffffffffffffffffffffffffabc7dd83accdc4d7e7ffffff',
    'fefefefefefefdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfefefefdfdfdf8f8f8f8f8'
        'f8f4f6f797d8f695d8f6f4f6f7fafafafcfcfcf8f8f8f4f6f787d3f668caf6e4'
        'f1f7f8f8f8fafafafcfcfcf4f6f786d3f669caf6d1ebf7d5edf7f4f6f7fafafa'
        'fcfcfcf4f6f799d9f6b4e2f656c3f5a4ddf7f7f8f8fafafafcfcfcf8f8f8f8f8'
        'f873ccf5278cc5dae4ecf8f8f8fafafafbfbfbf7f7f7f8f8f8f3f5f66698bf63'
        '97bff2f4f5f9f9f9fdfdfdf1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1fdfdfd',
    'ffffffffffffffffffffffffd6f1fda0defbb1e4fbfefefeffffffffffffffff'
        'ffd4f0fd5bc7f865cbf8e5f6fdffffffffffffffffffd4f0fd5bc7f865cbf8e5'
        'f6fdffffffffffffffffffd4f0fd5bc7f865cbf8d7f1fdcfeefdd2effdfefefe'
        'ffffffd4f0fd6dcdf8d2effd69ccf856c5f8c5ebfcfffffffffffffffffffbfd'
        'fe54c4f72cb5f3a7d6efffffffffffffffffffffffffffffffc9ecfc1873ac1b'
        '68a5d9e6f0ffffffffffffffffffffffffffffffc2d6e671a1c78cb3d1fdfefe',
  ];

  /// Largest [AppIconThumbnail.distanceTo] still counting as a default
  /// icon: sizes of one default artwork are within 5 of each other, and
  /// app icons measured were at least 14 away from every default.
  static const double maxDistance = 8;

  /// Smallest icon compared: tiny ones blur into each other.
  static const int minSize = 64;

  static final List<AppIconThumbnail> _defaults = [
    for (final hex in _thumbnails) AppIconThumbnail.fromHex(hex),
  ];

  /// Whether [thumbnail] looks like one of Flutter's default icons.
  static bool matches(AppIconThumbnail thumbnail) => _defaults.any(
    (reference) => reference.distanceTo(thumbnail) <= maxDistance,
  );
}
