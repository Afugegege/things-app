import 'dart:convert';
import 'decoration_layer.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String folder;
  final bool isPinned;
  final int? backgroundColor;
  final String? backgroundImage;
  
  final String? stickerEmoji; 
  final String? buttonLabel;
  final String? buttonLink;
  final int? buttonColor;
  final String? themeId;

  final String widgetType; // 'standard', 'album', etc.
  final List<DecorationLayer> designLayers;
  
  // NEW: Album Support
  final List<String> images;

  String get plainTextContent {
    if (content.isEmpty) return "";
    try {
      if (content.trim().startsWith('[') && content.contains('insert')) {
        final List<dynamic> delta = jsonDecode(content);
        return delta.map((op) {
          if (op is Map<String, dynamic> && op.containsKey('insert')) {
            return op['insert'].toString();
          }
          return "";
        }).join().trim();
      }
      return content;
    } catch (e) {
      return content;
    }
  }

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.folder = 'Uncategorised',
    this.isPinned = false,
    this.backgroundColor,
    this.backgroundImage,
    this.stickerEmoji,
    this.buttonLabel,
    this.buttonLink,
    this.buttonColor,
    this.themeId,
    this.widgetType = 'standard',
    this.designLayers = const [],
    this.images = const [],
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      folder: json['folder'] ?? 'Uncategorised',
      isPinned: json['isPinned'] ?? false,
      backgroundColor: json['backgroundColor'],
      backgroundImage: json['backgroundImage'],
      stickerEmoji: json['stickerEmoji'],
      buttonLabel: json['buttonLabel'],
      buttonLink: json['buttonLink'],
      buttonColor: json['buttonColor'],
      themeId: json['themeId'],
      widgetType: json['widgetType'] ?? 'standard',
      designLayers: (json['designLayers'] as List<dynamic>?)
          ?.map((e) => DecorationLayer.fromJson(e))
          .toList() ?? [],
      images: List<String>.from(json['images'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'folder': folder,
    'isPinned': isPinned,
    'backgroundColor': backgroundColor,
    'backgroundImage': backgroundImage,
    'stickerEmoji': stickerEmoji,
    'buttonLabel': buttonLabel,
    'buttonLink': buttonLink,
    'buttonColor': buttonColor,
    'themeId': themeId,
    'widgetType': widgetType,
    'designLayers': designLayers.map((l) => l.toJson()).toList(),
    'images': images,
  };

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? updatedAt,
    String? folder,
    bool? isPinned,
    int? backgroundColor,
    String? backgroundImage,
    String? stickerEmoji,
    String? buttonLabel,
    String? buttonLink,
    int? buttonColor,
    String? themeId,
    String? widgetType,
    List<DecorationLayer>? designLayers,
    List<String>? images,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folder: folder ?? this.folder,
      isPinned: isPinned ?? this.isPinned,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      stickerEmoji: stickerEmoji ?? this.stickerEmoji,
      buttonLabel: buttonLabel ?? this.buttonLabel,
      buttonLink: buttonLink ?? this.buttonLink,
      buttonColor: buttonColor ?? this.buttonColor,
      themeId: themeId ?? this.themeId,
      widgetType: widgetType ?? this.widgetType,
      designLayers: designLayers ?? this.designLayers,
      images: images ?? this.images,
    );
  }
}