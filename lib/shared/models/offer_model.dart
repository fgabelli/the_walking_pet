import 'package:cloud_firestore/cloud_firestore.dart';

enum OfferType {
  discountCode,
  externalLink,
}

class OfferModel {
  final String id;
  final String userId; // Business owner ID
  final String title;
  final String description;
  final String imageUrl;
  final OfferType type;
  final String? discountCode;
  final String? affiliateLink;
  final String partnerName; // Business name
  final double? discountPercentage;
  final DateTime createdAt;
  final DateTime expiresAt;

  const OfferModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.type,
    this.discountCode,
    this.affiliateLink,
    required this.partnerName,
    this.discountPercentage,
    required this.createdAt,
    required this.expiresAt,
  });

  factory OfferModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OfferModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      type: OfferType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => OfferType.externalLink,
      ),
      discountCode: data['discountCode'],
      affiliateLink: data['affiliateLink'],
      partnerName: data['partnerName'] ?? '',
      discountPercentage: (data['discountPercentage'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'type': type.name,
      'discountCode': discountCode,
      'affiliateLink': affiliateLink,
      'partnerName': partnerName,
      'discountPercentage': discountPercentage,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }
}
