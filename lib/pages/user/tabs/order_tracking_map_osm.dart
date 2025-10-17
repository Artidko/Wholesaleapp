// lib/pages/user/tabs/order_tracking_map_osm.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class OrderTrackingMapOSM extends StatefulWidget {
  final String orderId;
  const OrderTrackingMapOSM({super.key, required this.orderId});

  @override
  State<OrderTrackingMapOSM> createState() => _OrderTrackingMapOSMState();
}

class _OrderTrackingMapOSMState extends State<OrderTrackingMapOSM> {
  final mapController = MapController();

  // ข้อมูลเส้นทาง/ผลลัพธ์
  List<LatLng> _route = [];
  double? _routeKm;
  double? _routeMin;

  // สำหรับ throttle การขอเส้นทาง
  LatLng? _lastFrom;
  LatLng? _lastTo;
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);

  // ใช้รีเซ็ตเส้นทางเมื่อเริ่มแชร์รอบใหม่
  String? _sessionId;

  static const _stale = Duration(seconds: 20);
  static const _throttleSecs = 8;

  // --- Routing (OSRM demo public) ---
  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    final movedEnough = _lastFrom == null ||
        _lastTo == null ||
        _distanceMeters(_lastFrom!, from) > 40 || // driver ขยับ > 40m
        _distanceMeters(_lastTo!, to) > 5; // ปลายทางขยับ > 5m
    final recent =
        DateTime.now().difference(_lastFetch).inSeconds < _throttleSecs;
    if (!movedEnough && recent) return;

    final url =
        'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}?overview=full&geometries=geojson&alternatives=false&steps=false';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw 'OSRM ${res.statusCode}';
      final body = json.decode(res.body);
      final route = body['routes'][0];

      final coords = (route['geometry']['coordinates'] as List)
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
      final meters = (route['distance'] as num).toDouble(); // m
      final seconds = (route['duration'] as num).toDouble(); // s

      if (!mounted) return;
      setState(() {
        _route = coords;
        _routeKm = meters / 1000.0;
        _routeMin = seconds / 60.0;
        _lastFrom = from;
        _lastTo = to;
        _lastFetch = DateTime.now();
      });
    } catch (_) {
      // fallback: เส้นตรง + ประมาณเวลาแบบหยาบ
      final m = _distanceMeters(from, to);
      if (!mounted) return;
      setState(() {
        _route = [from, to];
        _routeKm = m / 1000.0;
        _routeMin = (_routeKm! / 30.0) * 60.0; // สมมติ 30 กม./ชม.
        _lastFrom = from;
        _lastTo = to;
        _lastFetch = DateTime.now();
      });
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const d = Distance();
    return d(a, b);
  }

  double _toFixed(double v, {int digits = 1}) =>
      double.parse(v.toStringAsFixed(digits));

  @override
  Widget build(BuildContext context) {
    final docRef =
        FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data!.data();
        if (data == null) {
          return const Scaffold(body: Center(child: Text('ไม่พบคำสั่งซื้อ')));
        }

        final status = (data['status'] ?? '') as String;
        final trackingActive = data['trackingActive'] == true;

        final dest = data['dest'] as Map<String, dynamic>?;
        final current = data['current'] as Map<String, dynamic>?;

        LatLng? destLatLng, curLatLng;
        DateTime? ts;
        String? sessionId;

        if (dest != null) {
          final lat = (dest['lat'] as num?)?.toDouble();
          final lng = (dest['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            destLatLng = LatLng(lat, lng);
          }
        }
        if (current != null) {
          final lat = (current['lat'] as num?)?.toDouble();
          final lng = (current['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            curLatLng = LatLng(lat, lng);
          }
          final t = current['ts'];
          if (t is Timestamp) ts = t.toDate();
          sessionId = current['sessionId'] as String?;
        }

        // อายุข้อมูล & ค้างหรือไม่
        final now = DateTime.now();
        final age = ts != null ? now.difference(ts) : const Duration(days: 999);
        final isStale = age > _stale;

        // ถ้า session เปลี่ยน = เริ่มแชร์รอบใหม่ → reset route
        if (sessionId != null && sessionId != _sessionId) {
          _sessionId = sessionId;
          _route.clear();
          _routeKm = null;
          _routeMin = null;
          _lastFrom = null;
          _lastTo = null;
        }

        // คำนวณเส้นทางเมื่อมีพิกัดสดทั้งสองฝั่ง และไม่ค้าง
        if (trackingActive &&
            curLatLng != null &&
            destLatLng != null &&
            !isStale) {
          _fetchRoute(curLatLng, destLatLng);
        }

        final initialCenter =
            curLatLng ?? destLatLng ?? const LatLng(13.7563, 100.5018);

        // markers
        final markers = <Marker>[
          if (curLatLng != null)
            Marker(
              point: curLatLng,
              width: 46,
              height: 46,
              child: Icon(
                Icons.delivery_dining,
                size: 36,
                color: (!trackingActive || isStale) ? Colors.grey : Colors.blue,
              ),
            ),
          if (destLatLng != null)
            Marker(
              point: destLatLng,
              width: 42,
              height: 42,
              child:
                  const Icon(Icons.location_pin, size: 36, color: Colors.red),
            ),
        ];

        // วงปลายทาง ~50m
        final circles = <CircleMarker>[
          if (destLatLng != null)
            CircleMarker(
              point: destLatLng,
              radius: 50,
              useRadiusInMeter: true,
              color: Colors.green.withOpacity(0.1),
              borderStrokeWidth: 1,
              borderColor: Colors.green,
            ),
        ];

        // ปรับกล้องให้ครอบทั้งสองจุดเมื่อขยับจริง
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (curLatLng != null && destLatLng != null) {
            final movedEnough = _lastFrom == null ||
                _distanceMeters(_lastFrom!, curLatLng) > 25 ||
                _lastTo == null ||
                _distanceMeters(_lastTo!, destLatLng) > 5;
            if (movedEnough) {
              final sw = LatLng(
                (curLatLng.latitude < destLatLng.latitude)
                    ? curLatLng.latitude
                    : destLatLng.latitude,
                (curLatLng.longitude < destLatLng.longitude)
                    ? curLatLng.longitude
                    : destLatLng.longitude,
              );
              final ne = LatLng(
                (curLatLng.latitude > destLatLng.latitude)
                    ? curLatLng.latitude
                    : destLatLng.latitude,
                (curLatLng.longitude > destLatLng.longitude)
                    ? curLatLng.longitude
                    : destLatLng.longitude,
              );
              mapController.fitCamera(
                CameraFit.bounds(
                  bounds: LatLngBounds(sw, ne),
                  padding: const EdgeInsets.all(56),
                ),
              );
            }
          }
        });

        // แบนเนอร์สถานะบนสุด
        final banner = (!trackingActive)
            ? 'กำลังรอไรเดอร์เริ่มแชร์ตำแหน่ง…'
            : (isStale ? 'กำลังรอสัญญาณพิกัด…' : 'ไรเดอร์กำลังเดินทาง…');

        final bannerColor = (!trackingActive)
            ? Colors.orange.shade50
            : (isStale ? Colors.orange.shade50 : Colors.green.shade50);

        final bannerTextColor = (!trackingActive)
            ? Colors.orange.shade700
            : (isStale ? Colors.orange.shade700 : Colors.green.shade700);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'ติดตามคำสั่งซื้อ #${widget.orderId} ${status.isNotEmpty ? '($status)' : ''}',
            ),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: bannerColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  banner,
                  style: TextStyle(
                    color: bannerTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: initialCenter,
                        initialZoom: 14,
                        interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.example.flutter_application_2',
                        ),
                        if (_route.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _route,
                                strokeWidth: 4.0,
                                color: (!trackingActive || isStale)
                                    ? Colors.grey
                                    : Colors.blue,
                              ),
                            ],
                          ),
                        if (circles.isNotEmpty) CircleLayer(circles: circles),
                        MarkerLayer(markers: markers),
                        const RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                                '© OpenStreetMap contributors'),
                          ],
                        ),
                      ],
                    ),

                    // Chip แสดงอายุข้อมูล
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Chip(
                        backgroundColor: (!trackingActive || isStale)
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        label: Text(
                          ts == null
                              ? 'ยังไม่เคยแชร์ตำแหน่ง'
                              : (!trackingActive
                                  ? 'ยังไม่เริ่มแชร์'
                                  : isStale
                                      ? 'อัปเดตล่าสุด ${age.inSeconds}s ที่แล้ว'
                                      : 'เรียลไทม์ • ${age.inSeconds}s'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // แสดงข้อมูลสรุประยะ/เวลา (เมื่อมี route สด)
              if (trackingActive &&
                  !isStale &&
                  _routeKm != null &&
                  _routeMin != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Text(
                    'เหลือระยะทาง: ${_toFixed(_routeKm!, digits: 1)} กม.  |  ประมาณ: ${_toFixed(_routeMin!, digits: 0)} นาที',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
