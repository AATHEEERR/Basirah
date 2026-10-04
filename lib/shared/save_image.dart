/// Saves or shares a PNG: on the web, the system share sheet when the
/// browser supports sharing files (phones), otherwise a download.
library;

export 'save_image_stub.dart' if (dart.library.js_interop) 'save_image_web.dart';
