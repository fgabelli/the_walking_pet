
class OfferModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String? discountCode;
  final String affiliateLink;
  final String partnerName;
  final double? discountPercentage;

  const OfferModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.discountCode,
    required this.affiliateLink,
    required this.partnerName,
    this.discountPercentage,
  });
}
