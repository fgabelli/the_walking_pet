import 'package:cloud_firestore/cloud_firestore.dart';

class AdCampaignModel {
  final String id;
  final String businessId;
  final String title;
  final String body;
  final String imageUrl;
  final String? videoUrl;
  final String ctaText;
  final String ctaLink; // Internal route or External URL
  final String targetZone;
  final int impressions;
  final int clicks;
  final bool isActive;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  
  // Location targeting properties
  final String targetingType; // 'national', 'regional', 'local'
  final String? targetRegion;  // e.g. 'Lombardia'
  final String? targetCity;    // e.g. 'Lissone'
  final double? targetLatitude;
  final double? targetLongitude;
  final double? targetRadiusKm;

  AdCampaignModel({
    required this.id,
    required this.businessId,
    required this.title,
    required this.body,
    required this.imageUrl,
    this.videoUrl,
    required this.ctaText,
    required this.ctaLink,
    required this.targetZone,
    this.impressions = 0,
    this.clicks = 0,
    this.isActive = true,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.targetingType = 'national',
    this.targetRegion,
    this.targetCity,
    this.targetLatitude,
    this.targetLongitude,
    this.targetRadiusKm,
  });

  factory AdCampaignModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdCampaignModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      videoUrl: data['videoUrl'],
      ctaText: data['ctaText'] ?? 'Scopri',
      ctaLink: data['ctaLink'] ?? '',
      targetZone: data['targetZone'] ?? '',
      impressions: data['impressions'] ?? 0,
      clicks: data['clicks'] ?? 0,
      isActive: data['isActive'] ?? true,
      startDate: data.containsKey('startDate') && data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate() 
          : (data.containsKey('createdAt') && data['createdAt'] != null 
              ? (data['createdAt'] as Timestamp).toDate() 
              : DateTime.now()),
      endDate: data.containsKey('endDate') && data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : (data.containsKey('expiresAt') && data['expiresAt'] != null 
              ? (data['expiresAt'] as Timestamp).toDate() 
              : DateTime.now().add(const Duration(days: 365))),
      createdAt: data.containsKey('createdAt') && data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      targetingType: data['targetingType'] ?? 'national',
      targetRegion: data['targetRegion'],
      targetCity: data['targetCity'],
      targetLatitude: (data['targetLatitude'] as num?)?.toDouble(),
      targetLongitude: (data['targetLongitude'] as num?)?.toDouble(),
      targetRadiusKm: (data['targetRadiusKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'ctaText': ctaText,
      'ctaLink': ctaLink,
      'targetZone': targetZone,
      'impressions': impressions,
      'clicks': clicks,
      'isActive': isActive,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'targetingType': targetingType,
      if (targetRegion != null) 'targetRegion': targetRegion,
      if (targetCity != null) 'targetCity': targetCity,
      if (targetLatitude != null) 'targetLatitude': targetLatitude,
      if (targetLongitude != null) 'targetLongitude': targetLongitude,
      if (targetRadiusKm != null) 'targetRadiusKm': targetRadiusKm,
    };
  }
}
