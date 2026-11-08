import 'url_cleaner_stub.dart'
    if (dart.library.js_interop) 'url_cleaner_web.dart';

void clearBrowserUrlParams([String path = '/']) {
  cleanBrowserUrl(path);
}
