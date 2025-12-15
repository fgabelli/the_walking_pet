import 'package:cloud_firestore/cloud_firestore.dart';

class AdCampaignModel {
  final String id;
  final String businessId;
  final String title;
  final String body;
  final String imageUrl;
  final String ctaText;
  final String ctaLink; // Internal route or External URL
  final String targetZone;
  final int impressions;
  final int clicks;
  final bool isActive;
  final DateTime expiresAt;
  final DateTime createdAt;

  AdCampaignModel({
    required this.id,
    required this.businessId,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.ctaText,
    required this.ctaLink,
    required this.targetZone,
    this.impressions = 0,
    this.clicks = 0,
    this.isActive = true,
    required this.expiresAt,
    required this.createdAt,
  });

  factory AdCampaignModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdCampaignModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      ctaText: data['ctaText'] ?? 'Scopri',
      ctaLink: data['ctaLink'] ?? '',
      targetZone: data['targetZone'] ?? '',
      impressions: data['impressions'] ?? 0,
      clicks: data['clicks'] ?? 0,
      isActive: data['isActive'] ?? true,
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'ctaText': ctaText,
      'ctaLink': ctaLink,
      'targetZone': targetZone,
      'impressions': impressions,
      'clicks': clicks,
      'isActive': isActive,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
