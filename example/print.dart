import 'dart:io';

import 'package:xdg_desktop_portal/xdg_desktop_portal.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: print <path>');
    return;
  }
  var path = args[0];

  var client = XdgDesktopPortalClient();
  var result = await client.print.preparePrint(title: 'Print Document');
  await client.print.print(File(path), token: result.token);

  await client.close();
}
