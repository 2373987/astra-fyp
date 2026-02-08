import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({super.key});

  @override
  State<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> {
  final MapController _mapController = MapController();

  // Backend base url (your FastAPI service)
  String get _baseUrl => "http://127.0.0.1:8000";

  LatLng? _me;
  String? _error;
  bool _loadingLocation = false;

  // Nearby real places
  bool _loadingNearby = false;
  List<_Place> _nearby = [];

  // Route
  bool _loadingRoute = false;
  List<LatLng> _routePoints = [];
  bool _showRoute = false;
  _Place? _selectedPlace;
  double? _routeDistanceM;
  double? _routeDurationS;

  // Demo overlays
  bool _showUnsafeZones = true;
  String _timeFilter = "All"; // All / Morning / Evening / Night

  // Search (IMPORTANT: do NOT setState on each keystroke)
  final TextEditingController _searchCtrl = TextEditingController();
  final ValueNotifier<String> _searchText = ValueNotifier<String>("");
  Timer? _searchDebounce;

  // Demo destination chips (fallback)
  final List<_DemoPlace> _demoPlaces = const [
    _DemoPlace("Demo Police Station", LatLng(51.5072, -0.1276)),
    _DemoPlace("Demo Hospital", LatLng(51.5010, -0.1180)),
    _DemoPlace("Demo University", LatLng(51.5033, -0.1200)),
    _DemoPlace("Demo Train Station", LatLng(51.5055, -0.1110)),
  ];

  // Reports (in-memory demo)
  final List<_SafetyReport> _reports = [
    _SafetyReport(
      id: "r1",
      title: "Poor lighting",
      message: "Street lights not working. Avoid at night.",
      timeOfDay: "Night",
      rating: 2,
      point: LatLng(51.5032, -0.1097),
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    _SafetyReport(
      id: "r2",
      title: "Crowded & safer",
      message: "Busy area, feels safer due to people around.",
      timeOfDay: "Evening",
      rating: 4,
      point: LatLng(51.5050, -0.1120),
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  final List<CircleMarker> _unsafeCircles = const [
    CircleMarker(
      point: LatLng(51.5042, -0.1085),
      radius: 80,
      useRadiusInMeter: true,
      color: Color.fromARGB(90, 255, 0, 0),
      borderStrokeWidth: 2,
      borderColor: Color.fromARGB(180, 255, 0, 0),
    ),
    CircleMarker(
      point: LatLng(51.5060, -0.1140),
      radius: 120,
      useRadiusInMeter: true,
      color: Color.fromARGB(80, 255, 165, 0),
      borderStrokeWidth: 2,
      borderColor: Color.fromARGB(160, 255, 165, 0),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchText.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Location
  // -------------------------
  Future<void> _loadLocation() async {
    setState(() {
      _loadingLocation = true;
      _error = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _error = "Location services are OFF.");
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = "Location permission denied in browser.");
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final me = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _me = me;
        _error = null;
      });

      _mapController.move(me, 15);

      // Load real nearby places once we have location
      await _loadNearby();
    } catch (e) {
      setState(() => _error = "Couldn’t access location.\n$e");
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  Future<void> _useDemoLocation() async {
    final demo = const LatLng(51.5045, -0.1090);
    setState(() {
      _me = demo;
      _error = null;
    });
    _mapController.move(demo, 15);
    await _loadNearby();
  }

  // -------------------------
  // Nearby real police/hospitals (UPDATED)
  // -------------------------
  Future<void> _loadNearby() async {
    if (_me == null) return;

    setState(() => _loadingNearby = true);

    try {
      final uri = Uri.parse(
        "$_baseUrl/nearby?lat=${_me!.latitude}&lon=${_me!.longitude}",
      );

      final res = await http.get(uri);
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      // IMPORTANT: backend returns ok:true/false
      if (data["ok"] != true) {
        debugPrint("Nearby not ok: ${data["message"]}");
        setState(() => _nearby = []);
        return;
      }

      final items = List<Map<String, dynamic>>.from(data["items"] ?? []);

      final places = items.map((m) {
        return _Place(
          type: (m["type"] ?? "unknown").toString(),
          name: (m["name"] ?? "Unknown place").toString(),
          lat: (m["lat"] as num).toDouble(),
          lon: (m["lon"] as num).toDouble(),
          phone: (m["phone"] ?? "").toString(),
        );
      }).toList();

      debugPrint("Nearby loaded: ${places.length}");
      if (places.isNotEmpty) {
        debugPrint(
          "First nearby: ${places.first.name} @ ${places.first.lat}, ${places.first.lon}",
        );
      }

      setState(() => _nearby = places);

      // Optional: auto-fit view to include nearby markers so you can SEE change
      if (places.isNotEmpty) {
        final pts = <LatLng>[
          _me!,
          ...places.map((p) => LatLng(p.lat, p.lon)),
        ];
        final bounds = LatLngBounds.fromPoints(pts);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
        );
      }
    } catch (e) {
      debugPrint("Nearby error: $e");
      setState(() => _nearby = []);
    } finally {
      if (mounted) setState(() => _loadingNearby = false);
    }
  }

  // -------------------------
  // Route helpers (smoothness)
  // -------------------------
  List<LatLng> _downsample(List<LatLng> pts, {int maxPoints = 250}) {
    if (pts.length <= maxPoints) return pts;
    final step = (pts.length / maxPoints).ceil();
    final out = <LatLng>[];
    for (int i = 0; i < pts.length; i += step) {
      out.add(pts[i]);
    }
    if (out.isEmpty || out.last != pts.last) out.add(pts.last);
    return out;
  }

  // -------------------------
  // Route (real, via backend /route)
  // -------------------------
  Future<void> _fetchRouteTo(_Place place) async {
    if (_me == null) return;

    setState(() {
      _loadingRoute = true;
      _routePoints = [];
      _routeDistanceM = null;
      _routeDurationS = null;
      _showRoute = true;
      _selectedPlace = place;
    });

    try {
      final uri = Uri.parse("$_baseUrl/route").replace(queryParameters: {
        "start_lat": _me!.latitude.toString(),
        "start_lon": _me!.longitude.toString(),
        "end_lat": place.lat.toString(),
        "end_lon": place.lon.toString(),
        "profile": "foot",
      });

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception("Route failed: ${res.statusCode}");
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data["ok"] != true) {
        throw Exception(data["message"] ?? "No route");
      }

      final rawPts = (data["points"] as List)
          .map((p) => LatLng(
                (p["lat"] as num).toDouble(),
                (p["lon"] as num).toDouble(),
              ))
          .toList();

      final pts = _downsample(rawPts, maxPoints: 250);

      setState(() {
        _routePoints = pts;
        _routeDistanceM = (data["distance_m"] as num?)?.toDouble();
        _routeDurationS = (data["duration_s"] as num?)?.toDouble();
      });

      if (pts.length >= 2) {
        final bounds = LatLngBounds.fromPoints(pts);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(60, 170, 60, 160),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Route error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _clearRoute() {
    setState(() {
      _showRoute = false;
      _routePoints = [];
      _routeDistanceM = null;
      _routeDurationS = null;
      _selectedPlace = null;
    });
  }

  // Demo route (for demo chips only)
  List<LatLng> _buildFakeRoute(LatLng a, LatLng b) {
    final points = <LatLng>[];
    const steps = 12;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final lat = a.latitude + (b.latitude - a.latitude) * t;
      final lon = a.longitude + (b.longitude - a.longitude) * t;
      final curve = sin(t * pi) * 0.0012;
      points.add(LatLng(lat + curve, lon));
    }
    return points;
  }

  void _selectDemoDestination(_DemoPlace place) {
    if (_me == null) return;
    setState(() {
      _showRoute = true;
      _routePoints = _buildFakeRoute(_me!, place.point);
      _selectedPlace = _Place(
        type: "demo",
        name: place.name,
        lat: place.point.latitude,
        lon: place.point.longitude,
        phone: "",
      );
    });

    final bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 170, 60, 160),
      ),
    );
  }

  // -------------------------
  // Reports
  // -------------------------
  List<_SafetyReport> get _filteredReports {
    if (_timeFilter == "All") return _reports;
    return _reports.where((r) => r.timeOfDay == _timeFilter).toList();
  }

  Future<void> _openAddReportDialog(LatLng point) async {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String timeOfDay = "Night";
    double rating = 3;

    final created = await showDialog<_SafetyReport>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Add Safety Report"),
          content: StatefulBuilder(
            builder: (ctx, setLocal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: "Title",
                        hintText: "e.g., Poor lighting",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: msgCtrl,
                      decoration: const InputDecoration(
                        labelText: "Message",
                        hintText: "Describe warning",
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text("Time: "),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: timeOfDay,
                          items: const [
                            DropdownMenuItem(value: "Morning", child: Text("Morning")),
                            DropdownMenuItem(value: "Evening", child: Text("Evening")),
                            DropdownMenuItem(value: "Night", child: Text("Night")),
                          ],
                          onChanged: (v) => setLocal(() => timeOfDay = v ?? "Night"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text("Rating: "),
                        Expanded(
                          child: Slider(
                            value: rating,
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: rating.round().toString(),
                            onChanged: (v) => setLocal(() => rating = v),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "1 = unsafe, 5 = very safe",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final msg = msgCtrl.text.trim();
                if (title.isEmpty || msg.isEmpty) return;

                final report = _SafetyReport(
                  id: "r${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(9)}",
                  title: title,
                  message: msg,
                  timeOfDay: timeOfDay,
                  rating: rating.round(),
                  point: point,
                  createdAt: DateTime.now(),
                );
                Navigator.pop(ctx, report);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );

    if (created != null) {
      setState(() => _reports.insert(0, created));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report added")),
        );
      }
    }
  }

  // -------------------------
  // Place popup (bottom sheet)
  // -------------------------
  void _openPlaceSheet(_Place p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill("Type: ${p.type}"),
                  if (_routeDistanceM != null && _selectedPlace == p)
                    _pill("Dist: ${(_routeDistanceM! / 1000).toStringAsFixed(2)} km"),
                  if (_routeDurationS != null && _selectedPlace == p)
                    _pill("ETA: ${(_routeDurationS! / 60).round()} min"),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _mapController.move(LatLng(p.lat, p.lon), 17);
                      },
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text("Zoom"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loadingRoute
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _fetchRouteTo(p);
                            },
                      icon: const Icon(Icons.directions),
                      label: const Text("Route"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (p.phone.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _callNumber(p.phone),
                    icon: const Icon(Icons.call),
                    label: Text("Call ${p.phone}"),
                  ),
                )
              else
                Text(
                  "Phone number not available (demo / API can be extended).",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri.parse("tel:$phone");
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Calling not supported on this device/browser.")),
        );
      }
      return;
    }
    await launchUrl(uri);
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text),
    );
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Safety Map"),
        actions: [
          IconButton(
            tooltip: "Refresh location",
            onPressed: _loadingLocation ? null : _loadLocation,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          _topControls(),
          Expanded(child: _buildMapBody()),
        ],
      ),
      floatingActionButton: _me == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _mapController.move(_me!, 16),
              icon: const Icon(Icons.my_location),
              label: const Text("Recenter"),
            ),
    );
  }

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: "Search demo places (presentation fallback)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 250),
                      () => _searchText.value = v.trim(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              if (_showRoute)
                IconButton(
                  tooltip: "Clear route",
                  onPressed: _clearRoute,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ONLY this part rebuilds while typing (not the map)
          ValueListenableBuilder<String>(
            valueListenable: _searchText,
            builder: (context, text, _) {
              if (text.isEmpty || _showRoute) return const SizedBox.shrink();

              final matches = _demoPlaces
                  .where((p) => p.name.toLowerCase().contains(text.toLowerCase()))
                  .toList();

              if (matches.isEmpty) return const SizedBox.shrink();

              return Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: matches
                      .map(
                        (p) => ActionChip(
                          label: Text(p.name),
                          onPressed: _me == null ? null : () => _selectDemoDestination(p),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),

          // UPDATED: always show a status line so you KNOW it loaded
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _loadingNearby
                    ? "Loading nearby police/hospitals…"
                    : (_nearby.isEmpty
                        ? "Nearby loaded: 0 (none returned)"
                        : "Nearby loaded: ${_nearby.length}"),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          DropdownButton<String>(
            value: _timeFilter,
            items: const [
              DropdownMenuItem(value: "All", child: Text("All times")),
              DropdownMenuItem(value: "Morning", child: Text("Morning")),
              DropdownMenuItem(value: "Evening", child: Text("Evening")),
              DropdownMenuItem(value: "Night", child: Text("Night")),
            ],
            onChanged: (v) => setState(() => _timeFilter = v ?? "All"),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Switch(
                  value: _showUnsafeZones,
                  onChanged: (v) => setState(() => _showUnsafeZones = v),
                ),
                const SizedBox(width: 6),
                const Text("Unsafe zones"),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _useDemoLocation,
            icon: const Icon(Icons.place_outlined),
            label: const Text("Demo loc"),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton(
                    onPressed: _loadingLocation ? null : _loadLocation,
                    child: const Text("Try again"),
                  ),
                  OutlinedButton(
                    onPressed: _useDemoLocation,
                    child: const Text("Use demo location"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_me == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final reportMarkers = _filteredReports.map((r) {
      final color = r.rating <= 2 ? Colors.red : (r.rating == 3 ? Colors.orange : Colors.green);

      return Marker(
        point: r.point,
        width: 48,
        height: 48,
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${r.title}: ${r.message}")),
            );
          },
          child: Icon(Icons.location_on, size: 40, color: color),
        ),
      );
    }).toList();

    final nearbyMarkers = _nearby.map((p) {
      final isPolice = p.type.toLowerCase().contains("police");
      final icon = isPolice ? Icons.local_police : Icons.local_hospital;
      final color = isPolice ? Colors.indigo : Colors.redAccent;

      return Marker(
        point: LatLng(p.lat, p.lon),
        width: 48,
        height: 48,
        child: GestureDetector(
          onTap: () => _openPlaceSheet(p),
          child: Icon(icon, size: 38, color: color),
        ),
      );
    }).toList();

    final myMarker = Marker(
      point: _me!,
      width: 50,
      height: 50,
      child: const Icon(Icons.my_location, size: 34),
    );

    return RepaintBoundary(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _me!,
          initialZoom: 15,
          onLongPress: (tapPos, latLng) => _openAddReportDialog(latLng),
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: "com.example.astra",
          ),
          if (_showUnsafeZones) CircleLayer(circles: _unsafeCircles),
          if (_showRoute && _routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints,
                  strokeWidth: 5,
                  color: Colors.blue.withOpacity(0.85),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              myMarker,
              ...nearbyMarkers,
              ...reportMarkers,
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------
// Models
// -------------------------
class _SafetyReport {
  final String id;
  final String title;
  final String message;
  final String timeOfDay;
  final int rating;
  final LatLng point;
  final DateTime createdAt;

  _SafetyReport({
    required this.id,
    required this.title,
    required this.message,
    required this.timeOfDay,
    required this.rating,
    required this.point,
    required this.createdAt,
  });
}

class _DemoPlace {
  final String name;
  final LatLng point;
  const _DemoPlace(this.name, this.point);
}

class _Place {
  final String type;
  final String name;
  final double lat;
  final double lon;
  final String phone;

  const _Place({
    required this.type,
    required this.name,
    required this.lat,
    required this.lon,
    required this.phone,
  });
}
