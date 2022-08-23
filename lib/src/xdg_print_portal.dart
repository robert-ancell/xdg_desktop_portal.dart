import 'dart:io';

import 'package:dbus/dbus.dart';

import 'xdg_portal_request.dart';

enum XdgPrintOrientation {
  landscape,
  portrait,
  reverseLandscape,
  reversePortrait
}

enum XdgPrintQuality { normal, high, low, draft }

/// Print settings.
class XdgPrintSettings {
  final Map<String, DBusValue> values;

  XdgPrintSettings(this.values);

  /// Page orientation.
  XdgPrintOrientation? get orientation => {
        'landscape': XdgPrintOrientation.landscape,
        'portrait': XdgPrintOrientation.portrait,
        'reverseLandscape': XdgPrintOrientation.reverseLandscape,
        'reverse_portrait': XdgPrintOrientation.reversePortrait
      }[values['orientation']?.asString() ?? ''];

  /// A paper name according to [PWG 5101.1-2002](ftp://ftp.pwg.org/pub/pwg/candidates/cs-pwgmsn10-20020226-5101.1.pdf).
  String get paperFormat => values['paper-format']?.asString() ?? '';

  /// Paper width, in millimeters.
  int get paperWidth => int.parse(values['paper-width']?.asString() ?? '0');

  /// Paper height, in millimeters.
  int get paperHeight => int.parse(values['paper-height']?.asString() ?? '0');

  /// The number of copies to print.
  int get nCopies => int.parse(values['n-copies']?.asString() ?? '0');

  /// The default paper source.
  String get defaultSource => values['default-source']?.asString() ?? '';

  /// Print quality.
  XdgPrintQuality get quality =>
      {
        'normal': XdgPrintQuality.normal,
        'high': XdgPrintQuality.high,
        'low': XdgPrintQuality.low,
        'draft': XdgPrintQuality.draft
      }[values['quality']?.asString() ?? ''] ??
      XdgPrintQuality.normal;

  String? get resolution => values['resolution']?.asString();

  /// Whether to use color.
  bool get useColor =>
      {'true': true, 'false': false}[values['user-color']?.asString() ?? ''] ??
      false;

  String? get duplex => values['duplex']?.asString();
  String? get reverse => values['reverse']?.asString();
  String? get mediaType => values['media-type']?.asString();
  String? get dither => values['dither']?.asString();
  String? get scale => values['scale']?.asString();
  String? get printPages => values['print-pages']?.asString();
  String? get pageRanges => values['page-ranges']?.asString();
  String? get pageSet => values['page-set']?.asString();
  String? get finishings => values['finishings']?.asString();
  String? get numberUp => values['number-up']?.asString();
  String? get numberUpLayout => values['number-up-layout']?.asString();
  String? get outputBin => values['output-bin']?.asString();
  String? get resolutionX => values['resolution-x']?.asString();
  String? get resolutionY => values['resolution-y']?.asString();
  String? get printerLpi => values['printer-lpi']?.asString();
  String? get outputBasename => values['outputBasename']?.asString();
  String? get outputFileFormat => values['outputFileFormat']?.asString();
  String? get outputUri => values['output-uri']?.asString();

  @override
  String toString() => '$runtimeType($values)';
}

/// Page setup.
class XdgPrintPageSetup {
  final Map<String, DBusValue> values;

  XdgPrintPageSetup(this.values);

  /// The PPD name.
  String get ppdName => values['PPDName']?.asString() ?? '';

  /// The name of the page setup.
  String get name => values['Name']?.asString() ?? '';

  /// User-visible name for the page setup.
  String get displayName => values['DisplayName']?.asString() ?? '';

  /// Paper width in millimeters.
  double get width => values['Width']?.asDouble() ?? 0;

  /// Paper height in millimeters.
  double get height => values['Height']?.asDouble() ?? 0;

  /// Top margin in millimeters.
  double get marginTop => values['MarginTop']?.asDouble() ?? 0;

  /// Bottom margin in millimeters.
  double get marginBottom => values['MarginBottom']?.asDouble() ?? 0;

  /// Left margin in millimeters.
  double get marginLeft => values['MarginLeft']?.asDouble() ?? 0;

  /// Right margin in millimeters.
  double get marginRight => values['MarginRight']?.asDouble() ?? 0;

  /// Page orientation.
  XdgPrintOrientation? get orientation => {
        'landscape': XdgPrintOrientation.landscape,
        'portrait': XdgPrintOrientation.portrait,
        'reverseLandscape': XdgPrintOrientation.reverseLandscape,
        'reverse_portrait': XdgPrintOrientation.reversePortrait
      }[values['Orientation']?.asString() ?? ''];

  @override
  String toString() => '$runtimeType($values)';
}

/// Result of a [XdgPrintPortal.preparePrint] call.
class XdgPreparePrintResult {
  /// Print settings chosen.
  final XdgPrintSettings settings;

  /// Page setup chosen.
  final XdgPrintPageSetup pageSetup;

  /// Token to pass to XdgPrintPortal.print] to use these settings.
  final int token;

  XdgPreparePrintResult(
      {required this.settings, required this.pageSetup, required this.token});

  @override
  String toString() =>
      '$runtimeType(settings: $settings, pageSetup: $pageSetup, token: $token)';
}

/// Portal for printing.
class XdgPrintPortal {
  final DBusRemoteObject _object;
  final String Function() _generateToken;

  XdgPrintPortal(this._object, this._generateToken);

  /// Get the version of this portal.
  Future<int> getVersion() => _object
      .getProperty('org.freedesktop.portal.Print', 'version',
          signature: DBusSignature('u'))
      .then((v) => v.asUint32());

  /// Presents a print dialog to the user and returns print settings and page setup.
  /// Call [print] with the returned token to print a document with these settings.
  Future<XdgPreparePrintResult> preparePrint(
      {String title = '',
      XdgPrintSettings? settings,
      XdgPrintPageSetup? pageSetup,
      String parentWindow = '',
      bool? modal}) async {
    var request = XdgPortalRequest(_object, () async {
      var options = <String, DBusValue>{};
      options['handle_token'] = DBusString(_generateToken());
      if (modal != null) {
        options['modal'] = DBusBoolean(modal);
      }
      var result = await _object.callMethod(
          'org.freedesktop.portal.Print',
          'PreparePrint',
          [
            DBusString(parentWindow),
            DBusString(title),
            DBusDict.stringVariant(settings?.values ?? {}),
            DBusDict.stringVariant(pageSetup?.values ?? {}),
            DBusDict.stringVariant(options)
          ],
          replySignature: DBusSignature('o'));
      return result.returnValues[0].asObjectPath();
    });
    var result = await request.stream.first;
    var settingsValues = result['settings']?.asStringVariantDict() ?? {};
    var pageSetupValues = result['page-setup']?.asStringVariantDict() ?? {};
    var token = result['token']?.asUint32() ?? 0;

    return XdgPreparePrintResult(
        settings: XdgPrintSettings(settingsValues),
        pageSetup: XdgPrintPageSetup(pageSetupValues),
        token: token);
  }

  /// Ask to print a [file].
  /// If [token] is provided, the document will be printed with the settings chosen in [preparePrint].
  Future<void> print(File file,
      {String title = '',
      String parentWindow = '',
      bool? modal,
      int? token}) async {
    var f = await file.open();
    var request = XdgPortalRequest(_object, () async {
      var options = <String, DBusValue>{};
      options['handle_token'] = DBusString(_generateToken());
      if (modal != null) {
        options['modal'] = DBusBoolean(modal);
      }
      if (token != null) {
        options['token'] = DBusUint32(token);
      }
      var result = await _object.callMethod(
          'org.freedesktop.portal.Print',
          'Print',
          [
            DBusString(parentWindow),
            DBusString(title),
            DBusUnixFd(ResourceHandle.fromFile(f)),
            DBusDict.stringVariant(options)
          ],
          replySignature: DBusSignature('o'));
      return result.returnValues[0].asObjectPath();
    });
    await request.stream.first;
    await f.close();
  }
}
