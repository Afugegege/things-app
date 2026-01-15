import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // [NEW] Import Geolocator
import '../services/storage_service.dart';

class RoamProvider extends ChangeNotifier {
  // Live Recording State
  bool _isRecording = false;
  List<LatLng> _currentPath = [];
  DateTime? _startTime;
  Duration _duration = Duration.zero;
  double _distanceKm = 0.0;
  Timer? _timer;
  StreamSubscription<Position>? _positionStream; // [NEW] Stream Subscription

  // History & Replay
  List<Map<String, dynamic>> _trips = [];
  bool _isReplaying = false;
  LatLng? _replayPosition;
  int _replayIndex = 0;
  Timer? _replayTimer;

  RoamProvider() {
    _loadTrips();
  }

  bool get isRecording => _isRecording;
  List<LatLng> get currentPath => _currentPath;
  Duration get duration => _duration;
  double get distanceKm => _distanceKm;
  List<Map<String, dynamic>> get trips => _trips;
  bool get isReplaying => _isReplaying;
  LatLng? get replayPosition => _replayPosition;

  // Calculate Average Pace (min/km)
  String get averagePace {
    if (_distanceKm <= 0) return "0:00";
    final totalMinutes = _duration.inSeconds / 60.0;
    final paceDecimal = totalMinutes / _distanceKm;
    final minutes = paceDecimal.floor();
    final seconds = ((paceDecimal - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  void _loadTrips() {
    _trips = StorageService.loadTrips();
    notifyListeners();
  }

  // --- RECORDING ---
  
  Future<void> startRecording() async {
    // [NEW] Check Permissions first
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _isRecording = true;
    _currentPath = [];
    _startTime = DateTime.now();
    _duration = Duration.zero;
    _distanceKm = 0.0;
    
    // Start Time Timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _duration = DateTime.now().difference(_startTime!);
      notifyListeners();
    });

    // [NEW] Start Location Stream
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Only notify if moved 5 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      addPoint(LatLng(position.latitude, position.longitude));
    });

    notifyListeners();
  }

  void addPoint(LatLng point) {
    if (!_isRecording) return;
    
    // Simple distance filter to reduce jitter
    if (_currentPath.isNotEmpty) {
      const Distance distance = Distance();
      final double move = distance.as(LengthUnit.Meter, _currentPath.last, point);
      // We already filter via Stream, but this is a double-check
      if (move > 2) { 
        _distanceKm += (move / 1000.0);
        _currentPath.add(point);
        notifyListeners();
      }
    } else {
      _currentPath.add(point);
      notifyListeners();
    }
  }

  void stopRecording(String type) {
    _timer?.cancel();
    _positionStream?.cancel(); // [NEW] Stop listening to GPS
    _isRecording = false;

    if (_currentPath.length > 2) {
      final newTrip = {
        'id': DateTime.now().toIso8601String(),
        'type': type, // 'Run', 'Walk', 'Cycle'
        'date': DateTime.now().toIso8601String(),
        'duration_sec': _duration.inSeconds,
        'distance_km': _distanceKm,
        'pace': averagePace,
        'points': _currentPath.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      };
      _trips.insert(0, newTrip);
      StorageService.saveTrips(_trips);
    }
    
    _currentPath = [];
    notifyListeners();
  }

  // --- REPLAY SYSTEM ---
  void startReplay(Map<String, dynamic> trip) {
    final List pointsJson = trip['points'];
    final List<LatLng> path = pointsJson.map((p) => LatLng(p['lat'], p['lng'])).toList();

    if (path.isEmpty) return;

    _isReplaying = true;
    _replayIndex = 0;
    _currentPath = path; 
    
    _replayTimer?.cancel();
    _replayTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_replayIndex < path.length) {
        _replayPosition = path[_replayIndex];
        _replayIndex++;
        notifyListeners();
      } else {
        stopReplay();
      }
    });
  }

  void stopReplay() {
    _isReplaying = false;
    _replayTimer?.cancel();
    _replayPosition = null;
    _currentPath = [];
    notifyListeners();
  }
}