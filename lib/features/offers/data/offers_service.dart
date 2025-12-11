import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/offer_model.dart';

class OffersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'offers';

  Stream<List<OfferModel>> getOffers() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OfferModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> createOffer(OfferModel offer, File? imageFile) async {
    String imageUrl = offer.imageUrl;

    if (imageFile != null) {
      final ref = _storage.ref().child('offer_images/${const Uuid().v4()}.jpg');
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }

    final docRef = _firestore.collection(_collection).doc();
    final newOffer = OfferModel(
      id: docRef.id,
      userId: offer.userId,
      title: offer.title,
      description: offer.description,
      imageUrl: imageUrl,
      type: offer.type,
      discountCode: offer.discountCode,
      affiliateLink: offer.affiliateLink,
      partnerName: offer.partnerName,
      discountPercentage: offer.discountPercentage,
      createdAt: DateTime.now(),
      expiresAt: offer.expiresAt,
    );

    await docRef.set(newOffer.toFirestore());
  }

  Future<void> deleteOffer(String offerId) async {
    await _firestore.collection(_collection).doc(offerId).delete();
  }
}
