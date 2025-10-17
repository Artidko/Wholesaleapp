import 'package:flutter/foundation.dart';
import '../services/driver_location_service.dart';

class DriverLocationProvider extends ChangeNotifier {
  final svc = DriverLocationService.instance;

  bool get isRunning => svc.isRunning;  // หรือเก็บ state แยก
  bool get navigationMode => svc.navigationMode;

  Future<void> start(String orderId, {bool history = false}) async {
    await svc.startTrackingOrder(orderId, alsoAppendHistory: history);
    notifyListeners();
  }

  Future<void> stop() async {
    await svc.stop();
    notifyListeners();
  }

  Future<void> toggleMode(String orderId) async {
    await svc.setNavigationMode(!svc.navigationMode, orderId: orderId);
    notifyListeners();
  }
}
