import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/driver_location_service.dart';

class DriverLocationProvider extends ChangeNotifier {
  final svc = DriverLocationService.instance;

  String? _orderId;
  String? _sessionId;

  bool get isRunning => svc.isRunning;
  bool get navigationMode => svc.navigationMode;
  String? get currentOrderId => _orderId;
  String? get currentSessionId => _sessionId;

  // สร้าง sessionId แบบง่าย ไม่ต้องพึ่งแพ็กเกจเสริม
  String _makeSessionId() {
    final n = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(1 << 32);
    return 'sess_${n}_$r';
    // ถ้าอยากใช้ uuid แทนก็เปลี่ยนมาได้ภายหลัง
  }

  /// เริ่มแชร์พิกัด — ต้องมี sessionId ทุกครั้ง
  Future<void> start(String orderId,
      {bool history = false, String? sessionId}) async {
    _orderId = orderId;
    _sessionId = sessionId ?? _makeSessionId();
    await svc.startTrackingOrder(
      orderId,
      sessionId: _sessionId!,
      alsoAppendHistory: history,
    );
    notifyListeners();
  }

  Future<void> stop() async {
    await svc.stop();
    _orderId = null;
    _sessionId = null;
    notifyListeners();
  }

  /// สลับโหมดความแม่นยำ (จะรีสตาร์ตให้อัตโนมัติภายใน service ถ้ากำลังรัน)
  Future<void> toggleMode() async {
    await svc.setNavigationMode(!svc.navigationMode);
    notifyListeners();
  }
}
