import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../providers/roam_provider.dart';
import '../../widgets/glass_container.dart';

class RoamScreen extends StatefulWidget {
  const RoamScreen({super.key});

  @override
  State<RoamScreen> createState() => _RoamScreenState();
}

class _RoamScreenState extends State<RoamScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final roamProvider = Provider.of<RoamProvider>(context);

    return LifeAppScaffold(
      title: "Roam",
      useDrawer: true, 
      child: Stack(
        children: [
          // 1. The Map
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(51.5, -0.09), 
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              // Draw Active Path
              if (roamProvider.currentPath.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: roamProvider.currentPath,
                      strokeWidth: 4.0,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
            ],
          ),

          // 2. Control Panel (Only visible when NOT recording, allowing Sheet to slide over)
          if (!roamProvider.isRecording)
            Positioned(
              bottom: 150, // Higher up to make room for sheet
              left: 20,
              right: 20,
              child: _buildStartSelector(roamProvider),
            ),

          // 3. Active Recording Controls (Fixed at bottom)
          if (roamProvider.isRecording)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildActiveTracker(roamProvider),
            ),
          
          // 4. History Sheet (Only when NOT recording)
          if (!roamProvider.isRecording)
            DraggableScrollableSheet(
              initialChildSize: 0.1,
              minChildSize: 0.1,
              maxChildSize: 0.6,
              builder: (context, scrollController) {
                return GlassContainer(
                  borderRadius: 25,
                  blur: 20,
                  opacity: 0.15,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4, 
                          decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2))
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text("RECENT ACTIVITY", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 15),
                      
                      if (roamProvider.trips.isEmpty)
                        const Center(child: Text("No trips yet. Go explore!", style: TextStyle(color: Colors.white38)))
                      else
                        ...roamProvider.trips.map((trip) {
                           final date = DateTime.parse(trip['date']);
                           return Container(
                             margin: const EdgeInsets.only(bottom: 10),
                             padding: const EdgeInsets.all(15),
                             decoration: BoxDecoration(
                               color: Colors.white.withOpacity(0.05),
                               borderRadius: BorderRadius.circular(15),
                             ),
                             child: Row(
                               children: [
                                 Container(
                                   padding: const EdgeInsets.all(10),
                                   decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), shape: BoxShape.circle),
                                   child: const Icon(Icons.directions_run, color: Colors.blueAccent, size: 20),
                                 ),
                                 const SizedBox(width: 15),
                                 Expanded(
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(trip['type'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                       Text("${date.day}/${date.month} • ${trip['pace']}/km", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                     ],
                                   ),
                                 ),
                                 Text(
                                   "${(trip['distance_km'] as double).toStringAsFixed(2)} km",
                                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                 ),
                               ],
                             ),
                           );
                        }),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- WIDGETS ---
  
  Widget _buildStartSelector(RoamProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _modeBtn(Icons.directions_run, "Workout", Colors.orange, () => provider.startRecording()),
          Container(width: 1, height: 40, color: Colors.white24),
          _modeBtn(Icons.flight_takeoff, "Trip", Colors.blue, () => provider.startRecording()),
        ],
      ),
    );
  }

  Widget _buildActiveTracker(RoamProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("TIME", "${provider.duration.inMinutes}:${(provider.duration.inSeconds % 60).toString().padLeft(2, '0')}"),
              _statItem("DIST (km)", provider.distanceKm.toStringAsFixed(2)),
              _statItem("PACE", provider.averagePace),
            ],
          ),
          const SizedBox(height: 20),
          FloatingActionButton(
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.stop),
            onPressed: () => provider.stopRecording('Workout'),
          )
        ],
      ),
    );
  }

  Widget _modeBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}