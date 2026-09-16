import 'package:dio/dio.dart';

/// 极简 WebDAV 客户端：MKCOL / PROPFIND / GET / PUT，兼容坚果云、群晖、Nextcloud、
/// 夸克/阿里等开放 WebDAV 的网盘（以实际提供的服务器地址、账号、密码为准）。
class WebDavClient {
  final String baseUrl; // 例如 https://dav.example.com/user/
  final String username;
  final String password;
  final Dio _dio;

  WebDavClient({required this.baseUrl, required this.username, required this.password})
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
          headers: {
            'Accept': '*/*',
          },
          validateStatus: (s) => s != null && s < 500,
        )) {
    if (username.isNotEmpty) {
      final token = base64Encode(('$username:$password').codeUnits);
      _dio.options.headers['Authorization'] = 'Basic $token';
    }
  }

  static String base64Encode(List<int> bytes) {
    const tbl = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final out = StringBuffer();
    var i = 0;
    while (i + 3 <= bytes.length) {
      final b0 = bytes[i], b1 = bytes[i + 1], b2 = bytes[i + 2];
      out.write(tbl[b0 >> 2]);
      out.write(tbl[((b0 & 3) << 4) | (b1 >> 4)]);
      out.write(tbl[((b1 & 15) << 2) | (b2 >> 6)]);
      out.write(tbl[b2 & 63]);
      i += 3;
    }
    final rem = bytes.length - i;
    if (rem == 1) {
      final b0 = bytes[i];
      out.write(tbl[b0 >> 2]);
      out.write(tbl[(b0 & 3) << 4]);
      out.write('==');
    } else if (rem == 2) {
      final b0 = bytes[i], b1 = bytes[i + 1];
      out.write(tbl[b0 >> 2]);
      out.write(tbl[((b0 & 3) << 4) | (b1 >> 4)]);
      out.write(tbl[(b1 & 15) << 2]);
      out.write('=');
    }
    return out.toString();
  }

  String _join(String path) {
    var b = baseUrl.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (!path.startsWith('/')) path = '/$path';
    return '$b$path';
  }

  /// 测试连接 + 认证
  Future<void> ping() async {
    final r = await _dio.request(
      _join('/'),
      options: Options(method: 'PROPFIND', headers: {'Depth': '0'}),
      data: '<?xml version="1.0"?><propfind xmlns="DAV:"><prop><displayname/></prop></propfind>',
    );
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw Exception('认证失败（$r.statusCode）：请检查 WebDAV 用户名和密码（部分网盘需用“应用密码”）');
    }
    if (r.statusCode == null || r.statusCode! >= 300) {
      throw Exception('服务器返回 ${r.statusCode}');
    }
  }

  /// 递归创建目录（已存在视为成功）
  Future<void> ensureDir(String path) async {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    var cur = '';
    for (final p in parts) {
      cur += '/$p';
      final r = await _dio.request(_join(cur), options: Options(method: 'MKCOL'));
      // 201 创建成功；405 已存在；其他报错
      if (r.statusCode != null && r.statusCode != 201 && r.statusCode != 405) {
        throw Exception('创建目录失败 $cur：${r.statusCode}');
      }
    }
  }

  /// 列出目录下文件名（仅一层）
  Future<List<String>> listFiles(String dir) async {
    final r = await _dio.request(
      _join(dir),
      options: Options(method: 'PROPFIND', headers: {'Depth': '1'}),
      data: '<?xml version="1.0"?><propfind xmlns="DAV:"><prop><displayname/><resourcetype/></prop></propfind>',
    );
    if (r.statusCode == null || r.statusCode! >= 300) {
      throw Exception('列目录失败：${r.statusCode}');
    }
    final body = r.data?.toString() ?? '';
    final hrefs = RegExp(r'<D?:?href[^>]*>([^<]+)</D?:?href>')
        .allMatches(body)
        .map((m) => Uri.decodeComponent(m.group(1)!))
        .toList();
    final names = <String>[];
    for (final h in hrefs) {
      final seg = h.split('/').where((s) => s.isNotEmpty).toList();
      if (seg.isEmpty) continue;
      final name = seg.last;
      if (name.endsWith('.json')) names.add(name);
    }
    return names.toSet().toList();
  }

  Future<String?> getText(String path) async {
    final r = await _dio.get<String>(_join(path),
        options: Options(responseType: ResponseType.plain));
    if (r.statusCode == 404) return null;
    if (r.statusCode == null || r.statusCode! >= 300) {
      throw Exception('下载失败：${r.statusCode}');
    }
    return r.data;
  }

  Future<void> putText(String path, String content) async {
    final r = await _dio.put(
      _join(path),
      data: content,
      options: Options(contentType: 'application/json; charset=utf-8'),
    );
    if (r.statusCode == null || r.statusCode! >= 300) {
      throw Exception('上传失败：${r.statusCode}');
    }
  }
}
