import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationService {
  DriverLocationService._();
  static final instance = DriverLocationService._();

  final _db = FirebaseFirestore.instance;
  StreamSubscription<Position>? _sub;

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return false;
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<void> startTrackingOrder(String orderId) async {
    final ok = await _ensurePermission();
    if (!ok) return;

    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      await _db.collection('orders').doc(orderId).update({
        'current': {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'speed': pos.speed,
          'heading': pos.heading,
          'ts': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
