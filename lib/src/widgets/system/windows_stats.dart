import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'system_stats.dart';

// Windows API yapıları (kernel32). Ek paket gerektirmemek için elle
// tanımlandı.

final class _FileTime extends Struct {
  @Uint32()
  external int low;

  @Uint32()
  external int high;

  int get value => (high << 32) | low;
}

final class _MemoryStatusEx extends Struct {
  @Uint32()
  external int dwLength;

  @Uint32()
  external int dwMemoryLoad;

  @Uint64()
  external int ullTotalPhys;

  @Uint64()
  external int ullAvailPhys;

  @Uint64()
  external int ullTotalPageFile;

  @Uint64()
  external int ullAvailPageFile;

  @Uint64()
  external int ullTotalVirtual;

  @Uint64()
  external int ullAvailVirtual;

  @Uint64()
  external int ullAvailExtendedVirtual;
}

final class _SystemPowerStatus extends Struct {
  @Uint8()
  external int acLineStatus;

  @Uint8()
  external int batteryFlag;

  @Uint8()
  external int batteryLifePercent;

  @Uint8()
  external int systemStatusFlag;

  @Uint32()
  external int batteryLifeTime;

  @Uint32()
  external int batteryFullLifeTime;
}

typedef _GetSystemTimesNative = Int32 Function(
  Pointer<_FileTime> idle,
  Pointer<_FileTime> kernel,
  Pointer<_FileTime> user,
);
typedef _GetSystemTimesDart = int Function(
  Pointer<_FileTime> idle,
  Pointer<_FileTime> kernel,
  Pointer<_FileTime> user,
);

typedef _GlobalMemoryStatusExNative = Int32 Function(
  Pointer<_MemoryStatusEx> status,
);
typedef _GlobalMemoryStatusExDart = int Function(
  Pointer<_MemoryStatusEx> status,
);

typedef _GetDiskFreeSpaceExNative = Int32 Function(
  Pointer<Utf16> directory,
  Pointer<Uint64> freeToCaller,
  Pointer<Uint64> total,
  Pointer<Uint64> totalFree,
);
typedef _GetDiskFreeSpaceExDart = int Function(
  Pointer<Utf16> directory,
  Pointer<Uint64> freeToCaller,
  Pointer<Uint64> total,
  Pointer<Uint64> totalFree,
);

typedef _GetSystemPowerStatusNative = Int32 Function(
  Pointer<_SystemPowerStatus> status,
);
typedef _GetSystemPowerStatusDart = int Function(
  Pointer<_SystemPowerStatus> status,
);

/// Windows'ta CPU, RAM, disk ve pil bilgisini doğrudan kernel32'den okur.
class WindowsStatsSource implements SystemStatsSource {
  WindowsStatsSource() {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    _getSystemTimes = kernel32
        .lookupFunction<_GetSystemTimesNative, _GetSystemTimesDart>(
            'GetSystemTimes');
    _globalMemoryStatusEx = kernel32.lookupFunction<
        _GlobalMemoryStatusExNative,
        _GlobalMemoryStatusExDart>('GlobalMemoryStatusEx');
    _getDiskFreeSpaceEx = kernel32.lookupFunction<_GetDiskFreeSpaceExNative,
        _GetDiskFreeSpaceExDart>('GetDiskFreeSpaceExW');
    _getSystemPowerStatus = kernel32.lookupFunction<
        _GetSystemPowerStatusNative,
        _GetSystemPowerStatusDart>('GetSystemPowerStatus');
  }

  late final _GetSystemTimesDart _getSystemTimes;
  late final _GlobalMemoryStatusExDart _globalMemoryStatusEx;
  late final _GetDiskFreeSpaceExDart _getDiskFreeSpaceEx;
  late final _GetSystemPowerStatusDart _getSystemPowerStatus;

  int? _prevIdle;
  int? _prevBusyTotal;

  @override
  Future<SystemSnapshot> read() async {
    return SystemSnapshot(
      cpu: _readCpu(),
      memUsed: _mem.$1,
      memTotal: _mem.$2,
      diskUsed: _disk.$1,
      diskTotal: _disk.$2,
      battery: _battery.$1,
      charging: _battery.$2,
      diskLabel: 'Disk ($_systemDrive)',
    );
  }

  String get _systemDrive {
    final drive = Platform.environment['SystemDrive'];
    return (drive == null || drive.isEmpty) ? 'C:' : drive;
  }

  double _readCpu() {
    final idle = calloc<_FileTime>();
    final kernel = calloc<_FileTime>();
    final user = calloc<_FileTime>();
    try {
      if (_getSystemTimes(idle, kernel, user) == 0) return 0;
      final idleValue = idle.ref.value;
      // Kernel zamanı boşta geçen zamanı da içerir.
      final total = kernel.ref.value + user.ref.value;
      final prevIdle = _prevIdle;
      final prevTotal = _prevBusyTotal;
      _prevIdle = idleValue;
      _prevBusyTotal = total;
      if (prevIdle == null || prevTotal == null) return 0;
      final totalDelta = total - prevTotal;
      if (totalDelta <= 0) return 0;
      final idleDelta = idleValue - prevIdle;
      return (1 - idleDelta / totalDelta).clamp(0.0, 1.0);
    } finally {
      calloc.free(idle);
      calloc.free(kernel);
      calloc.free(user);
    }
  }

  (int, int) get _mem {
    final status = calloc<_MemoryStatusEx>();
    try {
      status.ref.dwLength = sizeOf<_MemoryStatusEx>();
      if (_globalMemoryStatusEx(status) == 0) return (0, 0);
      final total = status.ref.ullTotalPhys;
      final available = status.ref.ullAvailPhys;
      return (total - available, total);
    } finally {
      calloc.free(status);
    }
  }

  (int, int) get _disk {
    final path = '$_systemDrive\\'.toNativeUtf16();
    final free = calloc<Uint64>();
    final total = calloc<Uint64>();
    final totalFree = calloc<Uint64>();
    try {
      if (_getDiskFreeSpaceEx(path, free, total, totalFree) == 0) {
        return (0, 0);
      }
      return (total.value - totalFree.value, total.value);
    } finally {
      malloc.free(path);
      calloc.free(free);
      calloc.free(total);
      calloc.free(totalFree);
    }
  }

  (int?, bool) get _battery {
    final status = calloc<_SystemPowerStatus>();
    try {
      if (_getSystemPowerStatus(status) == 0) return (null, false);
      final flag = status.ref.batteryFlag;
      final percent = status.ref.batteryLifePercent;
      // 128 = pil yok, 255 = bilinmiyor.
      if (flag == 128 || flag == 255 || percent == 255) return (null, false);
      return (percent, status.ref.acLineStatus == 1);
    } finally {
      calloc.free(status);
    }
  }
}
