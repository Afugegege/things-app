enum RoamType { fitness, travel }

class RoamSession {
  final String id;
  final String title;
  final RoamType type;
  final DateTime startTime;
  DateTime? endTime;
  
  List<RoamPoint> path; 
  
  double? totalDistance; 
  double? averageSpeed; 
  double? caloriesBurned;
  
  List<RoamStop> stops; 
  List<String> photoIds; 
  String? travelJournalEntry;

  RoamSession({
    required this.id, 
    required this.title, // [FIX] Added missing title
    required this.type,
    required this.startTime,
    this.path = const [],
    this.stops = const [],
    this.photoIds = const [],
  });
}

class RoamPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitude; 
  final double? speed;   

  // [FIX] Changed 'lat/lng' to 'latitude/longitude' to match the fields above
  RoamPoint({
    required this.latitude, 
    required this.longitude, 
    required this.timestamp, 
    this.altitude, 
    this.speed
  });
}

class RoamStop {
  final String name;
  final String description; // [FIX] Added if missing or optional
  final double latitude;
  final double longitude;
  final List<String> photos; 

  // [FIX] Changed 'lat/lng' to 'latitude/longitude'
  RoamStop({
    required this.name, 
    this.description = '', 
    required this.latitude, 
    required this.longitude, 
    this.photos = const []
  });
}