import 'dart:typed_data';

import 'package:http/http.dart' as http;

const String defaultBundleName = 'app.appmap';

const String bundleQueryParam = 'map';

bool get hasExplicitBundleTarget {
  final String? value = Uri.base.queryParameters[bundleQueryParam];
  return value != null && value.isNotEmpty;
}

Uri? startupBundleUri() {
  final String? param = Uri.base.queryParameters[bundleQueryParam];
  final String target = (param == null || param.isEmpty)
      ? defaultBundleName
      : param;
  final Uri? parsed = Uri.tryParse(target);
  if (parsed == null) {
    return null;
  }
  final Uri resolved = Uri.base.resolveUri(parsed);
  if (!resolved.isScheme('http') && !resolved.isScheme('https')) {
    return null;
  }
  return resolved;
}

Future<Uint8List?> loadStartupBundleBytes() async {
  final Uri? uri = startupBundleUri();
  if (uri == null) {
    return null;
  }
  final http.Response response = await http.get(uri);
  if (response.statusCode != 200) {
    return null;
  }
  final Uint8List bytes = response.bodyBytes;
  if (bytes.length < 2 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
    return null;
  }
  return bytes;
}
