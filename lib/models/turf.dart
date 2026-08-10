/// A turf/sports-ground listing, as returned by the turf list, turf
/// detail, and booking endpoints. Fields are nullable/defaulted where the
/// API is known to omit them in some responses (e.g. the list endpoint
/// returns fewer fields than the detail endpoint).
class Turf {
  final int id;
  final String name;
  final String type;
  final String? description;
  final String? area;
  final String? imageUrl;
  final List<String> imageUrls;
  final String locationName;
  final String locationAddress;
  final double? latitude;
  final double? longitude;
  final String priceText;
  final String rating;
  final int reviewsCount;
  final bool isOnlinePaymentActive;
  final bool isPartPaymentActive;
  /// Nullable rather than defaulted here: the two screens that read this
  /// field disagree on what a missing value should mean (one treats it as
  /// available-by-default, the other as unavailable) — preserved as-is
  /// rather than silently unified, each call site applies its own `??`.
  final bool? isPayAtLocationActive;
  final double cancellationFee;
  final int cancellationHours;
  final List<dynamic> sports;
  final List<dynamic> facilities;
  final List<dynamic> equipments;

  const Turf({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.area,
    this.imageUrl,
    this.imageUrls = const [],
    required this.locationName,
    required this.locationAddress,
    this.latitude,
    this.longitude,
    this.priceText = '₹1,000 / hr',
    this.rating = '0.0',
    this.reviewsCount = 0,
    this.isOnlinePaymentActive = false,
    this.isPartPaymentActive = false,
    this.isPayAtLocationActive,
    this.cancellationFee = 0.0,
    this.cancellationHours = 0,
    this.sports = const [],
    this.facilities = const [],
    this.equipments = const [],
  });

  bool get hasRating => rating != '0.0' && rating != '0';

  factory Turf.fromJson(Map<String, dynamic> json) {
    double? parseNum(dynamic v) {
      if (v == null) return null;
      return v is double ? v : double.tryParse(v.toString());
    }

    return Turf(
      id: json['id'] as int,
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      description: json['description'],
      area: json['area'],
      imageUrl: json['image_url'],
      imageUrls: json['image_urls'] != null ? List<String>.from(json['image_urls']) : const [],
      locationName: json['location_name'] ?? '',
      locationAddress: json['location_address'] ?? '',
      latitude: parseNum(json['latitude']),
      longitude: parseNum(json['longitude']),
      priceText: json['price_text'] ?? '₹1,000 / hr',
      rating: (json['rating'] ?? '0.0').toString(),
      reviewsCount: json['reviews_count'] ?? 0,
      isOnlinePaymentActive: json['is_online_payment_active'] ?? false,
      isPartPaymentActive: json['is_part_payment_active'] ?? false,
      isPayAtLocationActive: json['is_pay_at_location_active'],
      cancellationFee: (json['cancellation_fee'] ?? 0.0).toDouble(),
      cancellationHours: json['cancellation_hours'] ?? 0,
      sports: json['sports'] != null ? List<dynamic>.from(json['sports']) : const [],
      facilities: json['facilities'] != null ? List<dynamic>.from(json['facilities']) : const [],
      equipments: json['equipments'] != null ? List<dynamic>.from(json['equipments']) : const [],
    );
  }
}
