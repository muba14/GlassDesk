import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Uygulama verilerinin tutulduğu klasör.
///
/// Her widget ayrı bir süreçte çalıştığı için ortak bir anahtar-değer
/// deposu yerine her widget kendi küçük JSON dosyasını kullanır; böylece
/// süreçler birbirinin verisinin üzerine yazmaz.
class AppPaths {
  AppPaths._();

  static Directory? _root;

  static Future<void> init() async {
    final base = await getApplicationSupportDirectory();
    useRoot(base);
  }

  /// Testlerde geçici bir klasör vermek için.
  static void useRoot(Directory dir) {
    dir.createSync(recursive: true);
    _root = dir;
  }

  static File file(String name) {
    final root = _root ?? Directory.systemTemp;
    return File('${root.path}${Platform.pathSeparator}$name');
  }
}

/// Basit, hataya dayanıklı JSON dosyası.
class JsonFile {
  JsonFile(this.file);

  JsonFile.named(String name) : file = AppPaths.file(name);

  final File file;

  Map<String, dynamic> read() {
    try {
      if (!file.existsSync()) return <String, dynamic>{};
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Bozuk ya da yarım yazılmış dosya: boş kabul et.
    }
    return <String, dynamic>{};
  }

  bool exists() => file.existsSync();

  void write(Map<String, dynamic> data) {
    final text = jsonEncode(data);
    try {
      file.parent.createSync(recursive: true);
      final tmp = File('${file.path}.tmp');
      tmp.writeAsStringSync(text, flush: true);
      tmp.renameSync(file.path);
    } catch (_) {
      try {
        file.writeAsStringSync(text, flush: true);
      } catch (_) {
        // Yazılamadıysa sessizce geç; bir sonraki kayıtta tekrar denenir.
      }
    }
  }

  void update(void Function(Map<String, dynamic> data) change) {
    final data = read();
    change(data);
    write(data);
  }
}
