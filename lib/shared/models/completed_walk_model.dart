import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a completed GPS-tracked walk session
class CompletedWalkModel {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final int durationMinutes;
  final int steps;
  final int caloriesBurned;
  final String? petPhotoUrl;
  final List<String> petIds; // Pets that joined this walk

  CompletedWalkModel({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    required this.durationMinutes,
    required this.steps,
    required this.caloriesBurned,
    this.petPhotoUrl,
    this.petIds = const [],
  });

  factory CompletedWalkModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompletedWalkModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      distanceKm: (data['distanceKm'] ?? 0.0).toDouble(),
      durationMinutes: data['durationMinutes'] ?? 0,
      steps: data['steps'] ?? 0,
      caloriesBurned: data['caloriesBurned'] ?? 0,
      petPhotoUrl: data['petPhotoUrl'],
      petIds: List<String>.from(data['petIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'steps': steps,
      'caloriesBurned': caloriesBurned,
      'petPhotoUrl': petPhotoUrl,
      'petIds': petIds,
    };
  }
}
