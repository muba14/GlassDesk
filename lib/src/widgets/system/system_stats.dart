import 'dart:io';

import 'windows_stats.dart';

/// Bir anlık sistem kullanım ölçümü.
class SystemSnapshot {
  const SystemSnapshot({
    required this.cpu,
    required this.memUsed,
    required this.memTotal,
    required this.diskUsed,
    required this.diskTotal,
    this.battery,
    this.charging = false,
    this.diskLabel = 'Disk',
  });

  static const empty = SystemSnapshot(
    cpu: 0,
    memUsed: 0,
    memTotal: 0,
    diskUsed: 0,
    diskTotal: 0,
  );

  /// 0–1 arası.
  final double cpu;
  final int memUsed;
  final int memTotal;
  final int diskUsed;
  final int diskTotal;

  /// 0–100, pil yoksa null.
  final int? battery;
  final bool charging;
  final String diskLabel;

  double get memRatio => memTotal == 0 ? 0 : memUsed / memTotal;
  double get diskRatio => diskTotal == 0 ? 0 : diskUsed / diskTotal;
}

abstract class SystemStatsSource {
  Future<SystemSnapshot> read();

  /// Çalışılan işletim sistemine uygun kaynağı döndürür.
  static SystemStatsSource platform() {
    if (Platform.isWindows) {
      try {
        return WindowsStatsSource();
      } catch (_) {
        return UnsupportedStatsSource();
      }
    }
    if (Platform.isLinux) return LinuxStatsSource();
    return UnsupportedStatsSource();
  }
}

class UnsupportedStatsSource implements SystemStatsSource {
  @override
  Future<SystemSnapshot> read() async => SystemSnapshot.empty;
}

/// Testler ve ekran görüntüleri için sabit değerler döndürür.
class FakeStatsSource implements SystemStatsSource {
  FakeStatsSource(this.snapshot);

  final SystemSnapshot snapshot;

  @override
  Future<SystemSnapshot> read() async => snapshot;
}

/// /proc/stat'tan okunan toplam ve boşta CPU zamanı.
class CpuTimes {
  const CpuTimes(this.idle, this.total);

  final int idle;
  final int total;

  /// İki ölçüm arasındaki CPU kullanım oranı (0–1).
  double usageSince(CpuTimes previous) {
    final totalDelta = total - previous.total;
    final idleDelta = idle - previous.idle;
    if (totalDelta <= 0) return 0;
    return (1 - idleDelta / totalDelta).clamp(0.0, 1.0);
  }
}

CpuTimes? parseProcStat(String content) {
  for (final line in content.split('\n')) {
    if (!line.startsWith('cpu ')) continue;
    final values = line
        .split(RegExp(r'\s+'))
        .skip(1)
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    if (values.length < 4) return null;
    final idle = values[3] + (values.length > 4 ? values[4] : 0);
    final total = values.fold<int>(0, (sum, v) => sum + v);
    return CpuTimes(idle, total);
  }
  return null;
}

/// /proc/meminfo → (kullanılan, toplam) bayt.
({int used, int total})? parseMeminfo(String content) {
  int? total;
  int? available;
  for (final line in content.split('\n')) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final value = int.tryParse(parts[1]);
    if (value == null) continue;
    if (parts[0] == 'MemTotal:') total = value * 1024;
    if (parts[0] == 'MemAvailable:') available = value * 1024;
  }
  if (total == null || available == null) return null;
  return (used: total - available, total: total);
}

/// `df -k /` çıktısı → (kullanılan, toplam) bayt.
({int used, int total})? parseDf(String content) {
  final lines =
      content.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.length < 2) return null;
  final cols = lines[1].trim().split(RegExp(r'\s+'));
  if (cols.length < 4) return null;
  final total = int.tryParse(cols[1]);
  final available = int.tryParse(cols[3]);
  if (total == null || available == null) return null;
  return (used: (total - available) * 1024, total: total * 1024);
}

class LinuxStatsSource implements SystemStatsSource {
  CpuTimes? _previous;
  ({int used, int total})? _disk;
  DateTime? _diskReadAt;

  @override
  Future<SystemSnapshot> read() async {
    var cpu = 0.0;
    try {
      final times = parseProcStat(await File('/proc/stat').readAsString());
      final prev = _previous;
      if (times != null && prev != null) cpu = times.usageSince(prev);
      _previous = times;
    } catch (_) {}

    var mem = (used: 0, total: 0);
    try {
      mem = parseMeminfo(await File('/proc/meminfo').readAsString()) ?? mem;
    } catch (_) {}

    // Disk bilgisi yavaş değişir; 30 saniyede bir yenile.
    final now = DateTime.now();
    if (_disk == null ||
        _diskReadAt == null ||
        now.difference(_diskReadAt!) > const Duration(seconds: 30)) {
      try {
        final result = await Process.run('df', ['-k', '/']);
        _disk = parseDf(result.stdout.toString());
        _diskReadAt = now;
      } catch (_) {}
    }

    int? battery;
    var charging = false;
    try {
      final dir = Directory('/sys/class/power_supply');
      if (dir.existsSync()) {
        for (final entry in dir.listSync()) {
          final name = entry.path.split('/').last;
          if (!name.startsWith('BAT')) continue;
          final cap = File('${entry.path}/capacity');
          if (cap.existsSync()) {
            battery = int.tryParse(cap.readAsStringSync().trim());
          }
          final status = File('${entry.path}/status');
          if (status.existsSync()) {
            charging = status.readAsStringSync().trim() == 'Charging';
          }
          break;
        }
      }
    } catch (_) {}

    return SystemSnapshot(
      cpu: cpu,
      memUsed: mem.used,
      memTotal: mem.total,
      diskUsed: _disk?.used ?? 0,
      diskTotal: _disk?.total ?? 0,
      battery: battery,
      charging: charging,
      diskLabel: 'Disk (/)',
    );
  }
}

/// Bayt → "7,4 GB" biçimi.
String formatBytes(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const tb = gb * 1024;
  if (bytes >= tb) return '${_dec(bytes / tb)} TB';
  if (bytes >= gb) return '${_dec(bytes / gb)} GB';
  return '${(bytes / (1024 * 1024)).round()} MB';
}

String _dec(double v) =>
    (v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1))
        .replaceAll('.', ',');
