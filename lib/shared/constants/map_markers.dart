import 'package:flutter/material.dart';

class MapMarkers {
  static const String defaultSmile = 'default';
  static const String laugh = 'laugh';
  static const String cool = 'cool';
  static const String love = 'love';
  static const String neutral = 'neutral';
  static const String feminine = 'feminine';
  static const String masculine = 'masculine';
  static const String mask = 'mask';

  static const Map<String, IconData> icons = {
    defaultSmile: Icons.sentiment_satisfied_rounded,
    laugh: Icons.sentiment_very_satisfied_rounded,
    cool: Icons.face_retouching_natural,
    love: Icons.favorite,
    neutral: Icons.face_3, // Using face_3 as neutral/mustache style
    feminine: Icons.face_2,
    masculine: Icons.face_6,
    mask: Icons.masks,
  };

  static IconData getIcon(String? id) {
    if (id == null || !icons.containsKey(id)) {
      return icons[defaultSmile]!;
    }
    return icons[id]!;
  }

  static const List<Map<String, dynamic>> availableMarkers = [
    {'id': defaultSmile, 'name': 'Sorriso'},
    {'id': laugh, 'name': 'Risata'},
    {'id': cool, 'name': 'Cool'},
    {'id': neutral, 'name': 'Serio'},
    {'id': feminine, 'name': 'Femminile'},
    {'id': masculine, 'name': 'Maschile'},
    {'id': mask, 'name': 'Misterioso'},
    {'id': love, 'name': 'Love'},
  ];
}
