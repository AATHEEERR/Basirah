import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Shares [png] through the share sheet on touch devices (phones, tablets)
/// that can share files, otherwise downloads it as [filename]. Desktop
/// browsers get the download: their share sheets cannot save the image.
Future<bool> saveOrShareImage(Uint8List png, String filename, {String? text}) async {
  final blob = web.Blob([png.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  if (web.window.matchMedia('(pointer: coarse)').matches) {
    final file = web.File([png.toJS].toJS, filename, web.FilePropertyBag(type: 'image/png'));
    final data = web.ShareData(files: [file].toJS, text: text ?? '');
    try {
      if (web.window.navigator.canShare(data)) {
        await web.window.navigator.share(data).toDart;
        return true;
      }
    } catch (_) {
      // The user closed the sheet or sharing failed: fall back to download.
    }
  }
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
