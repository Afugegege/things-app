import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/roam_provider.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../widgets/glass_container.dart';

class RoamScreen extends StatefulWidget {
  const RoamScreen({super.key});

  @override
  State<RoamScreen> createState() => _RoamScreenState();
}

class _RoamScreenState extends State<RoamScreen> {
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _roamScaffoldKey = GlobalKey<ScaffoldState>();
  
  StreamSubscription<Position>? _positionStream;
  LatLng _currentPos = const LatLng(40.7128, -74.0060); // Default placeholder
  bool _followUser = true;
  bool _showHeatmap = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    _updateLoc(pos);

    const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen((Position p) {
      _updateLoc(p);
      Provider.of<RoamProvider>(context, listen: false).addPoint(LatLng(p.latitude, p.longitude));
    });
  }

  void _updateLoc(Position p) {
    if (!mounted) return;
    setState(() {
      _currentPos = LatLng(p.latitude, p.longitude);
    });
    if (_followUser) _mapController.move(_currentPos, 16.0);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roam = Provider.of<RoamProvider>(context);

    // Prepare Heatmap Data (Simulated with Circles)
    final List<CircleMarker> heatmapCircles = [];
    if (_showHeatmap) {
      for (var trip in roam.trips) {
        final List points = trip['points'];
        // Sample every 5th point to save performance
        for (int i = 0; i < points.length; i += 5) {
          final p = points[i];
          heatmapCircles.add(
            CircleMarker(
              point: LatLng(p['lat'], p['lng']),
              color: Colors.orangeAccent.withOpacity(0.1), // Very transparent
              useRadiusInMeter: true,
              radius: 20, // 20 meter radius
              borderStrokeWidth: 0,
            ),
          );
        }
      }
    }

    return Scaffold(
      key: _roamScaffoldKey,
      backgroundColor: Colors.black,
      
      // HISTORY DRAWER (End Drawer)
      endDrawer: Drawer(
        backgroundColor: const Color(0xFF1C1C1E),
        child: Column(
          children: [
            const SizedBox(height: 50),
            const Text("ACTIVITY HISTORY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const Divider(color: Colors.white12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: roam.trips.length,
                itemBuilder: (context, index) {
                  final trip = roam.trips[index];
                  return ListTile(
                    title: Text(trip['type'] ?? 'Activity', style: const TextStyle(color: Colors.white)),
                    subtitle: Text("${(trip['distance_km'] as double).toStringAsFixed(2)} km • ${trip['date'].toString().substring(0, 10)}", style: const TextStyle(color: Colors.white54)),
                    trailing: const Icon(Icons.play_arrow, color: Colors.cyanAccent),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      roam.startReplay(trip);
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),

      body: Stack(
        children: [
          // MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPos,
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) setState(() => _followUser = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.things.app',
                tileBuilder: (context, widget, tile) {
                   return ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      -1,  0,  0, 0, 255,
                       0, -1,  0, 0, 255,
                       0,  0, -1, 0, 255,
                       0,  0,  0, 1,   0,
                    ]),
                    child: widget,
                  );
                },
              ),
              
              // HEATMAP OVERLAY
              if (_showHeatmap) CircleLayer(circles: heatmapCircles),

              // CURRENT PATH
              if (roam.currentPath.isNotEmpty)
                PolylineLayer(polylines: [Polyline(points: roam.currentPath, strokeWidth: 4.0, color: Colors.cyanAccent)]),

              // REPLAY
              if (roam.isReplaying && roam.replayPosition != null)
                 MarkerLayer(markers: [Marker(point: roam.replayPosition!, child: const Icon(Icons.circle, color: Colors.greenAccent, size: 15))]),
              
              // USER
              if (!roam.isReplaying)
                MarkerLayer(markers: [Marker(point: _currentPos, child: const Icon(Icons.navigation, color: Colors.white, size: 30))]),
            ],
          ),

          // HEADER CONTROLS
          Positioned(
            top: 50, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.arrow_back, color: Colors.white)),
                ),
                // Heatmap Toggle
                GestureDetector(
                  onTap: () => setState(() => _showHeatmap = !_showHeatmap),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: _showHeatmap ? Colors.orange : Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [Icon(Icons.layers, size: 16, color: _showHeatmap ? Colors.black : Colors.white), const SizedBox(width: 5), Text("Heatmap", style: TextStyle(color: _showHeatmap ? Colors.black : Colors.white, fontWeight: FontWeight.bold))]),
                  ),
                ),
                // History Drawer
                GestureDetector(
                  onTap: () => _roamScaffoldKey.currentState?.openEndDrawer(),
                  child: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.history, color: Colors.white)),
                ),
              ],
            ),
          ),

          // BOTTOM CONTROL PANEL
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: roam.isRecording 
                ? _buildRecordingUI(roam) 
                : (roam.isReplaying ? _buildReplayUI(roam) : _buildIdleUI(roam)),
            ),
          ),
          
          // Re-Center
          if (!_followUser)
            Positioned(
              top: 110, right: 20,
              child: FloatingActionButton.small(
                backgroundColor: Colors.white,
                child: const Icon(Icons.gps_fixed, color: Colors.black),
                onPressed: () => setState(() { _followUser = true; _mapController.move(_currentPos, 16.0); }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIdleUI(RoamProvider roam) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("READY TO ROAM", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5)),
          Text("Start Activity", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        FloatingActionButton(backgroundColor: Colors.greenAccent, onPressed: () => roam.startRecording(), child: const Icon(Icons.play_arrow, color: Colors.black)),
      ],
    );
  }

  Widget _buildRecordingUI(RoamProvider roam) {
    final String duration = "${roam.duration.inMinutes}:${(roam.duration.inSeconds % 60).toString().padLeft(2, '0')}";
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("LIVE TRACKING", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(duration, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          Row(children: [const Icon(Icons.map, color: Colors.white54, size: 14), const SizedBox(width: 4), Text("${roam.distanceKm.toStringAsFixed(2)} km", style: const TextStyle(color: Colors.white70))]),
        ]),
        FloatingActionButton(backgroundColor: Colors.red, onPressed: () => roam.stopRecording('Run'), child: const Icon(Icons.stop, color: Colors.white)),
      ],
    );
  }

  Widget _buildReplayUI(RoamProvider roam) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("REPLAYING TRIP...", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        TextButton(onPressed: roam.stopReplay, child: const Text("CLOSE", style: TextStyle(color: Colors.white54))),
      ],
    );
  }
}