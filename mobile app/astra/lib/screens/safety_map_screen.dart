import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({super.key});

  @override
  State<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> {
  LatLng? _me;
  String? _error;
  bool _loading = false;

  // Optional: for controlling map moves
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loading = true;
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

      if (permission == LocationPermission.denied) {
        setState(() => _error = "Location permission denied.");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _error =
            "Location permission is permanently denied. Please enable it in Settings.");
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

      // If map is already built, recenter
      _mapController.move(me, 15);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Safety Map"),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadLocation,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh location",
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _me == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                _mapController.move(_me!, 16);
              },
              icon: const Icon(Icons.my_location),
              label: const Text("Recenter"),
            ),
    );
  }

  Widget _buildBody() {
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
              ElevatedButton(
                onPressed: _loading ? null : _loadLocation,
                child: const Text("Try again"),
              ),
            ],
          ),
        ),
      );
    }

    if (_me == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _me!,
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: "com.example.astra",
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _me!,
              width: 40,
              height: 40,
              child: const Icon(Icons.my_location, size: 36),
            ),
          ],
        ),
      ],
    );
  }
}
