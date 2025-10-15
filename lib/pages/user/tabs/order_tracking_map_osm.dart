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

  // ข้อมูลเส้นทางปัจจุบัน
  List<LatLng> _route = [];
  double? _routeKm;
  double? _routeMin;

  // เก็บจุดล่าสุด เพื่อกันเรียก API ซ้ำถี่ๆ
  LatLng? _lastFrom;
  LatLng? _lastTo;
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);

  // --- Routing (OSRM demo) ---
  // NOTE: สำหรับ production แนะนำเปลี่ยนไปใช้ OpenRouteService / MapTiler / GraphHopper พร้อม key
  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    // throttle: เรียกไม่บ่อยเกินไป หรือเมื่อจุดขยับจริงๆ
    final movedEnough = _lastFrom == null ||
        _lastTo == null ||
        _distanceMeters(_lastFrom!, from) > 40 || // rider ขยับ > ~40m
        _distanceMeters(_lastTo!, to) > 5; // ปลายทางเปลี่ยน > ~5m
    final recent = DateTime.now().difference(_lastFetch).inSeconds < 8;
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
          .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      final meters = (route['distance'] as num).toDouble(); // หน่วย: m
      final seconds = (route['duration'] as num).toDouble(); // หน่วย: s

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
      // fallback: วาดเส้นตรงแบบง่าย และคำนวณโดยประมาณ
      final m = _distanceMeters(from, to);
      if (!mounted) return;
      setState(() {
        _route = [from, to];
        _routeKm = m / 1000.0;
        // สมมติวิ่งในเมือง ~30 กม/ชม
        _routeMin = (_routeKm! / 30.0) * 60.0;
        _lastFrom = from;
        _lastTo = to;
        _lastFetch = DateTime.now();
      });
    }
  }

  double _toFixed(double v, {int digits = 1}) =>
      double.parse(v.toStringAsFixed(digits));

  double _distanceMeters(LatLng a, LatLng b) {
    const d = Distance();
    return d(a, b);
  }

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
        final dest = data['dest'] as Map<String, dynamic>?;
        final current = data['current'] as Map<String, dynamic>?;

        LatLng? destLatLng, curLatLng;
        if (dest != null) {
          destLatLng = LatLng(
              (dest['lat'] as num).toDouble(), (dest['lng'] as num).toDouble());
        }
        if (current != null) {
          curLatLng = LatLng((current['lat'] as num).toDouble(),
              (current['lng'] as num).toDouble());
        }

        // ขอเส้นทางเมื่อมีทั้งสองพิกัด
        if (curLatLng != null && destLatLng != null) {
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
              child: const Icon(Icons.delivery_dining,
                  size: 36, color: Colors.blue),
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

        // วงกลมปลายทาง ~50m
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

        // ปรับกล้องให้เห็นทั้งสองจุดครั้งแรก/เมื่อเปลี่ยนมากพอ
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (curLatLng != null && destLatLng != null) {
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
        });

        return Scaffold(
          appBar: AppBar(
            title: Text(
                'ติดตามคำสั่งซื้อ #${widget.orderId} ${status.isNotEmpty ? '($status)' : ''}'),
          ),
          body: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_2',
              ),
              if (_route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
              if (circles.isNotEmpty) CircleLayer(circles: circles),
              MarkerLayer(markers: markers),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          bottomNavigationBar: (_routeKm != null && _routeMin != null)
              ? Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Text(
                    'เหลือระยะทาง: ${_toFixed(_routeKm!, digits: 1)} กม.  |  ประมาณ: ${_toFixed(_routeMin!, digits: 0)} นาที',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              : null,
        );
      },
    );
  }
}
