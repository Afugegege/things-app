import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart'; // Required for saving image
import 'package:share_plus/share_plus.dart'; // Required for sharing
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
  final GlobalKey _globalKey = GlobalKey(); // For Screenshot
  final String _mapUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // State for Viewing History & Sharing
  List<LatLng> _viewingPath = [];
  bool _isViewingHistory = false;
  bool _isSharing = false; // Hides UI for screenshot
  Map<String, dynamic>? _activeSummaryTrip; // Trip currently being summarized/shared

  @override
  Widget build(BuildContext context) {
    final roamProvider = Provider.of<RoamProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    // Logic to determine what to show on map
    final List<LatLng> displayPath = _isViewingHistory ? _viewingPath : roamProvider.currentPath;
    final LatLng initialCenter = displayPath.isNotEmpty 
        ? displayPath.last 
        : const LatLng(51.509364, -0.128928);

    // [FIX] Auto-center map when recording and path updates
    if (roamProvider.isRecording && roamProvider.currentPath.isNotEmpty && !_isViewingHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(roamProvider.currentPath.last, _mapController.camera.zoom);
      });
    }

    return LifeAppScaffold(
      title: "ROAM",
      useDrawer: true, 
      child: RepaintBoundary( // [NEW] Wraps content for screenshot
        key: _globalKey,
        child: Stack(
          children: [
            // 1. FULL SCREEN MAP
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter, 
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapUrl,
                  userAgentPackageName: 'com.lifeos.app',
                ),
                if (displayPath.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: displayPath,
                        strokeWidth: 5.0,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
                if (displayPath.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: displayPath.first, // Start
                        width: 15, height: 15,
                        child: Container(decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      ),
                      Marker(
                        point: displayPath.last, // End
                        width: 20, height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // 2. SHARE OVERLAY (Visible only during sharing)
            if (_isSharing && _activeSummaryTrip != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      stops: const [0.6, 1.0]
                    )
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.public, color: Colors.blueAccent, size: 30),
                          const SizedBox(width: 10),
                          Text("ROAM", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(_activeSummaryTrip!['type'].toString().toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _shareStat("DISTANCE", "${(_activeSummaryTrip!['distance_km'] as double).toStringAsFixed(2)} km"),
                          _shareStat("TIME", _activeSummaryTrip!['duration'] ?? "0:00"),
                          _shareStat("PACE", _activeSummaryTrip!['pace'] ?? "0'00\""),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

            // 3. MAIN CONTROLS (Hidden during share)
            if (!_isSharing) ...[
              // IDLE CONTROLS
              if (!roamProvider.isRecording)
                Positioned(
                  bottom: 140, 
                  left: 20, right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isViewingHistory)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CupertinoButton(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            minSize: 0,
                            borderRadius: BorderRadius.circular(20),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Icon(Icons.close, color: Colors.white, size: 16), SizedBox(width: 5), Text("Close Route", style: TextStyle(color: Colors.white, fontSize: 12))],
                            ),
                            onPressed: () {
                              setState(() {
                                _isViewingHistory = false;
                                _viewingPath = [];
                              });
                            },
                          ),
                        ),
                      _buildHistorySheet(roamProvider, isDark, textColor, secondaryTextColor),
                      const SizedBox(height: 15),
                      _buildStartButton(context, roamProvider),
                    ],
                  ),
                ),

              // ACTIVE RECORDING UI
              if (roamProvider.isRecording)
                Positioned(
                  bottom: 140, 
                  left: 20, right: 20,
                  child: _buildActiveTracker(roamProvider, theme),
                ),
                
              // HEADER FADE
              Positioned(
                top: 0, left: 0, right: 0, height: 100,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.scaffoldBackgroundColor, theme.scaffoldBackgroundColor.withOpacity(0)],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      )
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- ACTIONS ---

  void _viewTripOnMap(Map<String, dynamic> trip) {
    // Parse points
    final List points = trip['points'];
    final List<LatLng> path = points.map((p) => LatLng(p['lat'], p['lng'])).toList();
    
    if (path.isEmpty) return;

    setState(() {
      _isViewingHistory = true;
      _viewingPath = path;
    });

    // Fit bounds (Simple approximation)
    double minLat = path.first.latitude;
    double maxLat = path.first.latitude;
    double minLng = path.first.longitude;
    double maxLng = path.first.longitude;

    for (var p in path) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController.move(LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), 14.5);
    _showSummaryDialog(context, trip);
  }

  Future<void> _captureAndShare(Map<String, dynamic> trip) async {
    // 1. Setup UI for sharing
    Navigator.pop(context); // Close dialog
    setState(() {
      _isSharing = true;
      _activeSummaryTrip = trip;
    });

    // 2. Wait for rebuild
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      // 3. Capture Screenshot
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 4. Save to Temp File
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/roam_share_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);

      // 5. Share
      await Share.shareXFiles(
        [XFile(file.path)], 
        text: 'Just finished a ${trip['type']} on Roam! 🌍 #LifeOS #Roam'
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to share image.")));
    } finally {
      // 6. Restore UI
      setState(() {
        _isSharing = false;
        _activeSummaryTrip = null;
      });
    }
  }

  // --- WIDGETS ---

  Widget _buildStartButton(BuildContext context, RoamProvider provider) {
    return CupertinoButton(
      color: Colors.blueAccent,
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.symmetric(vertical: 16),
      onPressed: () => _showActivityTypeSelector(context, provider),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
          SizedBox(width: 10),
          Text("START ACTIVITY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildActiveTracker(RoamProvider provider, ThemeData theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(25),
      borderRadius: 30,
      opacity: 0.9, 
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.circle, color: Colors.redAccent, size: 12),
                const SizedBox(width: 8),
                Text("RECORDING", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ]),
              Text(provider.durationString, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 20, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("DISTANCE", "${provider.distanceKm.toStringAsFixed(2)} km", theme),
              _statItem("PACE", provider.averagePace, theme),
              _statItem("SPEED", "${(provider.distanceKm / (provider.duration.inMinutes/60 + 0.001)).toStringAsFixed(1)} km/h", theme),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    provider.stopRecording('Activity'); 
                    Future.delayed(const Duration(milliseconds: 100), () {
                       if (provider.trips.isNotEmpty) {
                         _viewTripOnMap(provider.trips.first);
                       }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.stop_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: GestureDetector(
                  onTap: () {}, 
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.pause_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHistorySheet(RoamProvider provider, bool isDark, Color textColor, Color secondaryColor) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      child: GlassContainer(
        borderRadius: 20,
        opacity: isDark ? 0.8 : 0.95,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("RECENT LOGS", style: TextStyle(color: secondaryColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            
            if (provider.trips.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: Text("No activities yet.\nStart recording to build your log!", 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondaryColor)
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: provider.trips.length,
                  separatorBuilder: (_, __) => const Divider(height: 10),
                  itemBuilder: (context, i) {
                    final trip = provider.trips[i];
                    final date = DateTime.parse(trip['date']);
                    return GestureDetector(
                      onTap: () => _viewTripOnMap(trip),
                      child: Container(
                        color: Colors.transparent, // Hit test
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(_getActivityIcon(trip['type']), color: Colors.orangeAccent, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(trip['type'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text("${date.day}/${date.month} • ${trip['duration'] ?? '0:00'}", style: TextStyle(color: secondaryColor, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text("${(trip['distance_km'] as double).toStringAsFixed(2)} km", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 5),
                            Icon(Icons.chevron_right, size: 16, color: secondaryColor.withOpacity(0.5)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _shareStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Run': return Icons.directions_run;
      case 'Bike': return Icons.directions_bike;
      case 'Hike': return Icons.hiking;
      default: return Icons.directions_walk;
    }
  }

  // --- DIALOGS ---

  void _showActivityTypeSelector(BuildContext context, RoamProvider provider) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("CHOOSE ACTIVITY", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _activityOption(Icons.directions_run, "Run", Colors.orange, () { Navigator.pop(ctx); provider.startRecording(); }),
                  _activityOption(Icons.directions_bike, "Bike", Colors.blue, () { Navigator.pop(ctx); provider.startRecording(); }),
                  _activityOption(Icons.hiking, "Hike", Colors.green, () { Navigator.pop(ctx); provider.startRecording(); }),
                  _activityOption(Icons.directions_walk, "Walk", Colors.purple, () { Navigator.pop(ctx); provider.startRecording(); }),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  void _showSummaryDialog(BuildContext context, Map<String, dynamic> trip) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Route Summary"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 50),
            const SizedBox(height: 15),
            Text("${(trip['distance_km'] as double).toStringAsFixed(2)} km", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            Text("Total Distance (${trip['type']})", style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem("TIME", trip['duration'] ?? "0:00", theme),
                _statItem("PACE", trip['pace'] ?? "0'00\"", theme),
              ],
            )
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.share, size: 18),
            label: const Text("Share"),
            onPressed: () => _captureAndShare(trip),
          ),
          TextButton(
            child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
  }
}