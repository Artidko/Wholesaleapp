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
  Position? _lastPos;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  // เก็บค่าไว้ใช้ตอน restart stream
  String? _lastOrderId;
  String? _sessionId;

  bool get isRunning => _sub != null;

  /// true = โหมดนำทาง, false = โหมดประหยัด
  bool navigationMode = true;

  int distanceFilter = 10; // m
  Duration minWriteInterval = const Duration(seconds: 1);
  double maxAcceptableAccuracyMeters = 100; // m
  double minDisplacementToWrite = 3; // m

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

    if (kIsWeb) {
      return LocationSettings(accuracy: acc, distanceFilter: distanceFilter);
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
      );
    }

    // Desktop/อื่น ๆ
    return LocationSettings(accuracy: acc, distanceFilter: distanceFilter);
  }

  /* ---------------- Firestore writes ---------------- */

  Future<void> _writeOrderCurrent(String orderId, Position pos) async {
    final now = DateTime.now();
    if (now.difference(_lastWrite) < minWriteInterval) return;

    if (_lastPos != null) {
      final d = Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (d < minDisplacementToWrite) return;
    }
    _lastWrite = now;
    _lastPos = pos;

    await _db.collection('orders').doc(orderId).set({
      'trackingActive': true, // เผื่อฝั่ง admin/เว็บไม่ได้ตั้ง
      'current': {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed': pos.speed, // m/s
        'heading': pos.heading,
        'acc': pos.accuracy, // m
        'sessionId': _sessionId, // ✅ เขียน session เสมอ
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

  /// เริ่มแชร์พิกัดของ [orderId]
  /// ต้องส่ง [sessionId] มาทุกครั้ง (สร้างใหม่ทุกครั้งที่กดเริ่มแชร์)
  Future<void> startTrackingOrder(
    String orderId, {
    required String sessionId,
    bool alsoAppendHistory = false,
  }) async {
    final ok = await _ensurePermission();
    if (!ok) return;

    _lastOrderId = orderId;
    _sessionId = sessionId;

    // เปิดแฟลกไว้ก่อน
    await _db.collection('orders').doc(orderId).set({
      'trackingActive': true,
      'current': {'sessionId': sessionId},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // seed จุดแรก
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
      // ปล่อยให้ไปตาม stream
    }

    await _sub?.cancel();
    _lastPos = null;
    _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

    _sub = Geolocator.getPositionStream(
      locationSettings: _buildSettings(),
    ).listen(
      (pos) async {
        try {
          if (pos.accuracy.isNaN || pos.accuracy > maxAcceptableAccuracyMeters)
            return;

          await _writeOrderCurrent(orderId, pos);

          if (alsoAppendHistory) {
            final sec = DateTime.now().second;
            if (sec % 20 == 0 || pos.speed > 1.5) {
              await _appendTrackingPoint(orderId, pos);
            }
          }
        } catch (_) {/* กันสตรีมหลุด */}
      },
      onError: (e, st) {/* ใส่ log ได้ */},
      cancelOnError: false,
    );
  }

  /// หยุดแชร์
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _lastPos = null;

    // ปิดแฟลกในเอกสารล่าสุด
    final id = _lastOrderId;
    if (id != null) {
      await _db.collection('orders').doc(id).set({
        'trackingActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// สลับความแม่นยำระหว่างงาน — ถ้ากำลังรันอยู่จะ restart ให้โดยใช้ order/session เดิม
  Future<void> setNavigationMode(bool enabled) async {
    navigationMode = enabled;
    if (_sub != null && _lastOrderId != null && _sessionId != null) {
      final orderId = _lastOrderId!;
      final session = _sessionId!;
      await stop();
      await startTrackingOrder(orderId, sessionId: session);
    }
  }
}
