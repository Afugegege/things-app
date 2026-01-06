class DecorationLayer {
  final String id;
  final String type; // 'emoji', 'image', 'frame'
  final String content; // The actual emoji char or asset path
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final int zIndex;

  DecorationLayer({
    required this.id,
    required this.type,
    required this.content,
    this.x = 0.5, // Center default
    this.y = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.zIndex = 0,
  });

  // Convert to JSON for saving (if you add persistence later)
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'content': content,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
    'zIndex': zIndex,
  };

  factory DecorationLayer.fromJson(Map<String, dynamic> json) {
    return DecorationLayer(
      id: json['id'],
      type: json['type'],
      content: json['content'],
      x: json['x'],
      y: json['y'],
      scale: json['scale'],
      rotation: json['rotation'],
      zIndex: json['zIndex'],
    );
  }
}