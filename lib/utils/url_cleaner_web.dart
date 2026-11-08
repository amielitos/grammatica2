import 'package:web/web.dart' as web;

void cleanBrowserUrl(String path) {
  try {
    web.window.history.replaceState(null, '', path);
  } catch (_) {}
}
