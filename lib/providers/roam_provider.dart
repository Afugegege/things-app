import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/storage_service.dart';

class RoamProvider extends ChangeNotifier {
  // Live Recording State
  bool _isRecording = false;
  List<LatLng> _currentPath = [];
  DateTime? _startTime;
  Duration _duration = Duration.zero;
  double _distanceKm = 0.0;
  Timer? _timer;

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
  void startRecording() {
    _isRecording = true;
    _currentPath = [];
    _startTime = DateTime.now();
    _duration = Duration.zero;
    _distanceKm = 0.0;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _duration = DateTime.now().difference(_startTime!);
      notifyListeners();
    });
    notifyListeners();
  }

  void addPoint(LatLng point) {
    if (!_isRecording) return;
    
    // Simple distance filter to reduce jitter (must move > 3 meters)
    if (_currentPath.isNotEmpty) {
      final Distance distance = const Distance();
      final double move = distance.as(LengthUnit.Meter, _currentPath.last, point);
      if (move > 3) {
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
    _isRecording = false;

    if (_currentPath.length > 2) {
      final newTrip = {
        'id': DateTime.now().toIso8601String(),
        'type': type, // 'Run', 'Walk', 'Cycle'
        'date': DateTime.now().toIso8601String(),
        'duration_sec': _duration.inSeconds,
        'distance_km': _distanceKm,
        'pace': averagePace,
        // Convert LatLng objects to simple Map for JSON storage
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
    // 1. Parse points
    final List pointsJson = trip['points'];
    final List<LatLng> path = pointsJson.map((p) => LatLng(p['lat'], p['lng'])).toList();

    if (path.isEmpty) return;

    // 2. Setup Replay
    _isReplaying = true;
    _replayIndex = 0;
    _currentPath = path; // Show the full path trace
    
    _replayTimer?.cancel();
    // 3. Fast forward loop (50ms updates)
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
    _currentPath = []; // Clear the trace line
    notifyListeners();
  }
}