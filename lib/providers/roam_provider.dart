import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; 
import '../services/storage_service.dart';

class RoamProvider extends ChangeNotifier {
  // Live Recording State
  bool _isRecording = false;
  List<LatLng> _currentPath = [];
  DateTime? _startTime;
  Duration _duration = Duration.zero;
  double _distanceKm = 0.0;
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;

  // History & Replay
  List<Map<String, dynamic>> _trips = [];
  bool _isReplaying = false;
  LatLng? _replayPosition;
  int _replayIndex = 0;
  Timer? _replayTimer;

  RoamProvider() {
    _loadTrips();
  }

  // --- GETTERS ---
  bool get isRecording => _isRecording;
  List<LatLng> get currentPath => _currentPath;
  Duration get duration => _duration;
  double get distanceKm => _distanceKm;
  List<Map<String, dynamic>> get trips => _trips;
  bool get isReplaying => _isReplaying;
  LatLng? get replayPosition => _replayPosition;

  // [FIX] Added formatted string for the UI
  String get durationString {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(_duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(_duration.inSeconds.remainder(60));
    return "${twoDigits(_duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  // Calculate Average Pace (min/km)
  String get averagePace {
    if (_distanceKm <= 0.001) return "0:00"; // Prevent division by zero
    final totalMinutes = _duration.inSeconds / 60.0;
    final paceDecimal = totalMinutes / _distanceKm;
    
    // Cap pace display for sanity (e.g. if GPS jumps)
    if (paceDecimal > 59) return "59:59"; 

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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Ideally show error to user, for now return
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    _isRecording = true;
    _currentPath = [];
    _startTime = DateTime.now();
    _duration = Duration.zero;
    _distanceKm = 0.0;
    
    // Start Time Timer
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        _duration = DateTime.now().difference(_startTime!);
        notifyListeners();
      }
    });

    // Start Location Stream
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Only notify if moved 5 meters
    );

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      addPoint(LatLng(position.latitude, position.longitude));
    });

    notifyListeners();
  }

  void addPoint(LatLng point) {
    if (!_isRecording) return;
    
    // Distance Filter
    if (_currentPath.isNotEmpty) {
      const Distance distance = Distance();
      final double move = distance.as(LengthUnit.Meter, _currentPath.last, point);
      
      // Filter jitter (move > 2 meters)
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
    _positionStream?.cancel();
    _isRecording = false;

    // Only save meaningful trips (> 2 points or > 10 meters)
    if (_currentPath.length > 2 && _distanceKm > 0.01) {
      final newTrip = {
        'id': DateTime.now().toIso8601String(),
        'type': type, // 'Run', 'Walk', 'Cycle'
        'date': DateTime.now().toIso8601String(),
        'duration': durationString, // Save formatted string for display
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
    if (trip['points'] == null) return;

    final List pointsJson = trip['points'];
    final List<LatLng> path = pointsJson.map((p) => LatLng(p['lat'], p['lng'])).toList();

    if (path.isEmpty) return;

    _isReplaying = true;
    _replayIndex = 0;
    _currentPath = path; 
    
    _replayTimer?.cancel();
    _replayTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
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