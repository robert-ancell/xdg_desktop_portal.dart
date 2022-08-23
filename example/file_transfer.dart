import 'dart:io';

import 'package:xdg_desktop_portal/xdg_desktop_portal.dart';

void usage() {
  print('Usage:');
  print('file_transfer send <paths>');
  print('file_transfer retrieve <key>');
}

void main(List<String> args) async {
  if (args.isEmpty) {
    usage();
    return;
  }
  var command = args[0];

  var client = XdgDesktopPortalClient();

  switch (command) {
    case 'send':
      if (args.length < 2) {
        usage();
      } else {
        var files = args.skip(1).map((p) => File(p));
        await for (var key in client.fileTransfer.sendFiles(files)) {
          print(key);
        }
      }

      break;
    case 'retrieve':
      if (args.length != 2) {
        usage();
      } else {
        var key = args[1];
        var paths = await client.fileTransfer.retrieveFiles(key);
        for (var path in paths) {
          print(path);
        }
      }
      break;
    default:
      usage();
      break;
  }

  await client.close();
}
