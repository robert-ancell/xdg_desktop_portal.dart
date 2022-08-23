import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';

class _SendFilesController {
  final DBusRemoteObject object;
  final Iterable<File> files;
  final bool writable;
  final bool autostop;

  late final StreamController<String> _controller;
  Stream<String> get stream => _controller.stream;

  StreamSubscription? _transferClosedSubscription;

  String? key;

  _SendFilesController(this.object, this.files,
      {this.writable = false, this.autostop = true}) {
    _controller =
        StreamController<String>(onListen: _onListen, onCancel: _onCancel);
  }

  Future<void> _onListen() async {
    var transferClosed = DBusSignalStream(object.client,
        interface: 'org.freedesktop.portal.FileTransfer',
        name: 'TransferClosed',
        path: object.path,
        signature: DBusSignature('s'));
    _transferClosedSubscription = transferClosed.listen((signal) {
      if (signal.values[0].asString() == key) {
        _controller.close();
      }
    });

    var openedFiles = <RandomAccessFile>[];
    for (var file in files) {
      openedFiles.add(await file.open());
    }
    var options = <String, DBusValue>{};
    if (writable) {
      options['writable'] = DBusBoolean(true);
    }
    if (!autostop) {
      options['autostop'] = DBusBoolean(false);
    }
    var result = await object.callMethod('org.freedesktop.portal.FileTransfer',
        'StartTransfer', [DBusDict.stringVariant(options)],
        replySignature: DBusSignature('s'));
    key = result.returnValues[0].asString();

    await object.callMethod(
        'org.freedesktop.portal.FileTransfer',
        'AddFiles',
        [
          DBusString(key!),
          DBusArray.unixFd(openedFiles.map((f) => ResourceHandle.fromFile(f))),
          DBusDict.stringVariant({})
        ],
        replySignature: DBusSignature(''));
    for (var f in openedFiles) {
      await f.close();
    }

    _controller.add(key!);
  }

  Future<void> _onCancel() async {
    await _transferClosedSubscription?.cancel();
    try {
      await object.callMethod('org.freedesktop.portal.FileTransfer',
          'StopTransfer', [DBusString(key!)],
          replySignature: DBusSignature(''));
    } on DBusMethodResponseException {
      // Ignore errors, as the session may have completed before the stop transfer request was received.
    }
  }
}

/// Portal to transfer files between applications.
class XdgFileTransferPortal {
  final DBusRemoteObject _object;

  XdgFileTransferPortal(this._object);

  /// Get the version of this portal.
  Future<int> getVersion() => _object
      .getProperty('org.freedesktop.portal.FileTransfer', 'version',
          signature: DBusSignature('u'))
      .then((v) => v.asUint32());

  /// Start a session to send [files].
  /// The stream will return a key that can be used by another application in [retrieveFiles].
  Stream<String> sendFiles(Iterable<File> files,
      {bool writable = false, bool autostop = true}) {
    var controller = _SendFilesController(_object, files,
        writable: writable, autostop: autostop);
    return controller.stream;
  }

  /// Retrieve files from another application using [key] that that application provided.
  Future<List<String>> retrieveFiles(String key) async {
    var result = await _object.callMethod('org.freedesktop.portal.FileTransfer',
        'RetrieveFiles', [DBusString(key), DBusDict.stringVariant({})],
        replySignature: DBusSignature('as'));
    return result.returnValues[0].asStringArray().toList();
  }
}
