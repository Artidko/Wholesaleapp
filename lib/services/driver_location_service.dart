// lib/services/driver_location_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationService {
  DriverLocationService._();
  static final instance = DriverLocationService._();

  final _db = FirebaseFirestore.instance;

  StreamSubscription<Position>? _sub;
  Position? _lastPos; // กัน jitter อีกชั้น
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  /// ให้ UI เช็คสถานะได้
  bool get isRunning => _sub != null;

  /// true = นำทาง (แม่นสุด), false = แม่น/ประหยัดขึ้น
  bool navigationMode = true;

  /// ขยับ >= X m จึงปล่อย event จาก sensor (ชั้นนอก)
  int distanceFilter = 10;

  /// เขียน Firestore ถี่สุดทุก ๆ X วินาที (ชั้นใน)
  Duration minWriteInterval = const Duration(seconds: 1);

  /// ทิ้งจุดที่ accuracy > X m
  double maxAcceptableAccuracyMeters = 100;

  /// ขยับน้อยกว่า X m ถือว่า jitter ไม่ต้องเขียน
  double minDisplacementToWrite = 3;

  /* ---------------- Permission & Settings ---------------- */

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  LocationSettings _buildSettings() {
    final acc = navigationMode
        ? LocationAccuracy.bestForNavigation
        : LocationAccuracy.best;

    // Web
    if (kIsWeb) {
      return LocationSettings(
        accuracy: acc,
        distanceFilter: distanceFilter,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: acc,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'กำลังติดตามตำแหน่ง',
          notificationText: 'อัปเดตพิกัดสำหรับงานจัดส่ง',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: acc,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        // ไม่ตั้ง distanceFilter เพื่อหลีกเลี่ยงพฤติกรรมต่างเวอร์ชัน
      );
    }

    // Desktop/อื่น ๆ
    return LocationSettings(
      accuracy: acc,
      distanceFilter: distanceFilter,
    );
  }

  /* ---------------- Firestore writes ---------------- */

  Future<void> _writeOrderCurrent(String orderId, Position pos) async {
    final now = DateTime.now();
    if (now.difference(_lastWrite) < minWriteInterval) return;

    // กัน jitter เพิ่ม: ถ้าแทบไม่ขยับ ไม่ต้องเขียน
    if (_lastPos != null) {
      final d = Geolocator.distanceBetween(
          _lastPos!.latitude, _lastPos!.longitude, pos.latitude, pos.longitude);
      if (d < minDisplacementToWrite) return;
    }
    _lastWrite = now;
    _lastPos = pos;

    await _db.collection('orders').doc(orderId).set({
      'current': {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed': pos.speed, // m/s
        'heading': pos.heading, // degree 0..360
        'acc': pos.accuracy, // m
        'ts': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _appendTrackingPoint(String orderId, Position pos) async {
    await _db.collection('orders').doc(orderId).collection('tracking').add({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'speed': pos.speed,
      'heading': pos.heading,
      'acc': pos.accuracy,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  /* ---------------- Public API ---------------- */

  /// เริ่มแชร์พิกัดของ orderId
  Future<void> startTrackingOrder(
    String orderId, {
    bool alsoAppendHistory = false,
  }) async {
    final ok = await _ensurePermission();
    if (!ok) return;

    // seed จุดแรก (กันว่าง)
    try {
      final first = await Geolocator.getCurrentPosition(
        desiredAccuracy: navigationMode
            ? LocationAccuracy.bestForNavigation
            : LocationAccuracy.best,
        timeLimit: const Duration(seconds: 8),
      );
      if (!first.accuracy.isNaN &&
          first.accuracy <= maxAcceptableAccuracyMeters) {
        await _writeOrderCurrent(orderId, first);
        if (alsoAppendHistory) await _appendTrackingPoint(orderId, first);
      }
    } catch (_) {
      // ปล่อยให้ไปตาม stream ต่อ
    }

    await _sub?.cancel();
    _lastPos = null;
    _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

    _sub =
        Geolocator.getPositionStream(locationSettings: _buildSettings()).listen(
      (pos) async {
        try {
          // กรองตำแหน่งแย่/ผิดปกติ
          if (pos.accuracy.isNaN || pos.accuracy > maxAcceptableAccuracyMeters)
            return;

          await _writeOrderCurrent(orderId, pos);

          if (alsoAppendHistory) {
            // เก็บเป็นช่วง ๆ เพื่อลด write
            final sec = DateTime.now().second;
            if (sec % 20 == 0 || pos.speed > 1.5) {
              await _appendTrackingPoint(orderId, pos);
            }
          }
        } catch (_) {
          /* อย่าให้ stream หลุด */
        }
      },
      onError: (e, st) {
        // คุณอาจใส่ log/report ที่นี่
      },
      cancelOnError: false,
    );
  }

  /// หยุดแชร์
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _lastPos = null;
  }

  /// สลับโปรไฟล์ความแม่นยำระหว่างใช้งาน (ถ้ากำลังรันอยู่ให้ restart)
  Future<void> setNavigationMode(bool enabled, {String? orderId}) async {
    navigationMode = enabled;
    if (_sub != null && orderId != null) {
      await stop();
      await startTrackingOrder(orderId);
    }
  }
}
