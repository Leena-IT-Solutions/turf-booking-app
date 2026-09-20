import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../models/turf.dart';
import '../widgets/db_icon_widget.dart';
import '../widgets/review_dialog.dart';
import 'turf_booking_screen.dart';

class TurfDetailScreen extends StatefulWidget {
  final Turf turf;
  final String? token;

  const TurfDetailScreen({super.key, required this.turf, this.token});

  @override
  State<TurfDetailScreen> createState() => _TurfDetailScreenState();
}

class _TurfDetailScreenState extends State<TurfDetailScreen> {
  List<dynamic> _reviews = [];
  bool _reviewsLoading = true;
  String _avgRating = '0.0';
  int _reviewsCount = 0;
  List<dynamic> _coupons = [];
  bool _couponsLoading = true;

  @override
  void initState() {
    super.initState();
    _avgRating = widget.turf.rating;
    _reviewsCount = widget.turf.reviewsCount;
    _fetchReviews();
    _fetchCoupons();
  }

  Future<void> _fetchCoupons() async {
    final turfId = widget.turf.id;
    try {
      final response = await ApiClient.get(Uri.parse('${ApiClient.baseUrl}/turfs/$turfId/coupons'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _coupons = data;
            _couponsLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _couponsLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching coupons: $e');
      if (mounted) {
        setState(() {
          _couponsLoading = false;
        });
      }
    }
  }

  Future<void> _fetchReviews() async {
    final turfId = widget.turf.id;
    try {
      final response = await ApiClient.get(Uri.parse('${ApiClient.baseUrl}/turfs/$turfId/reviews'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        double totalRating = 0;
        for (var rev in data) {
          totalRating += (rev['rating'] as num).toDouble();
        }
        if (mounted) {
          setState(() {
            _reviews = data;
            _reviewsLoading = false;
            _reviewsCount = data.length;
            _avgRating = data.isNotEmpty ? (totalRating / data.length).toStringAsFixed(1) : '0.0';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _reviewsLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      if (mounted) {
        setState(() {
          _reviewsLoading = false;
        });
      }
    }
  }

  Future<bool> _submitReview(int rating, String comment) async {
    final turfId = widget.turf.id;
    if (widget.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.')),
      );
      return false;
    }

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/turfs/$turfId/reviews'),
        headers: ApiClient.authHeaders(widget.token),
        body: jsonEncode({
          'rating': rating,
          'comment': comment,
        }),
      );

      if (response.statusCode == 200) {
        await _fetchReviews();
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['message'] ?? 'Failed to submit review.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error submitting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Failed to submit review.')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final name = widget.turf.name;
    final type = widget.turf.type;
    final description = widget.turf.description ?? 'No description provided.';
    final area = widget.turf.area ?? '';
    final locationName = widget.turf.locationName;
    final locationAddress = widget.turf.locationAddress;
    final price = widget.turf.priceText;
    final rating = _avgRating;
    final hasRating = rating != '0.0' && rating != '0';
    final sports = widget.turf.sports;
    final facilities = widget.turf.facilities;
    final equipments = widget.turf.equipments;
    final imageUrls = widget.turf.imageUrls;
    final latitude = widget.turf.latitude;
    final longitude = widget.turf.longitude;

    final isOnlinePayment = widget.turf.isOnlinePaymentActive;
    final isPartPayment = widget.turf.isPartPaymentActive;
    final isPayAtLocation = widget.turf.isPayAtLocationActive == true;
    final isCancellationActive = widget.turf.isCancellationActive;
    final cancellationHours = widget.turf.cancellationHours;
    final cancellationFee = widget.turf.cancellationFee;
    final bookingOpenDays = widget.turf.bookingOpenDays;
    final partPaymentType = widget.turf.partPaymentType;
    final partPaymentValue = widget.turf.partPaymentValue;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image / Gallery Header with back button
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: isDark ? Colors.black45 : Colors.white70,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrls.isNotEmpty
                  ? PageView.builder(
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          imageUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            child: Icon(
                              type == 'Synthetic' ? Icons.grass : Icons.stadium,
                              size: 80,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        type == 'Synthetic' ? Icons.grass : Icons.stadium,
                        size: 80,
                        color: theme.colorScheme.primary,
                      ),
                    ),
            ),
          ),

          // Turf details content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Rating Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locationName.isNotEmpty ? locationName : name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (locationName.isNotEmpty &&
                                locationName.trim().toLowerCase() != name.trim().toLowerCase()) ...[
                              const SizedBox(height: 4),
                              Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                       if (hasRating) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                rating,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Area and Type Badge
                  Row(
                    children: [
                      _buildChip(type, theme.colorScheme.primary.withValues(alpha: 0.1), theme.colorScheme.primary),
                      if (area.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildChip(area, Colors.grey.withValues(alpha: 0.1), Colors.grey),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Location & Contact Card
                  Card(
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E2022) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!, width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on, color: theme.colorScheme.primary, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locationName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      locationAddress,
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () => _launchNavigation(latitude, longitude, locationAddress),
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.navigation_rounded, color: theme.colorScheme.primary, size: 20),
                                ),
                                tooltip: 'Navigate',
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                          const SizedBox(height: 12),
                          // Quick Contact Row (Call & WhatsApp)
                          Row(
                            children: [
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _callTurf(widget.turf.effectiveContactNumber),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.phone_in_talk_rounded, color: theme.colorScheme.primary, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Call',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _messageWhatsApp(
                                      widget.turf.effectiveWhatsappNumber,
                                      locationName.isNotEmpty ? locationName : name,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF25D366).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF25D366).withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'WhatsApp',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1EBE5D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'About Turf',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.grey, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Sports tag list
                  if (sports.isNotEmpty) ...[
                    Text(
                      'Sports Available',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildVerticalList(sports, theme.colorScheme.primary, theme),
                    const SizedBox(height: 24),
                  ],

                  // Facilities tag list
                  if (facilities.isNotEmpty) ...[
                    Text(
                      'Facilities & Amenities',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildVerticalList(facilities, Colors.blue, theme),
                    const SizedBox(height: 24),
                  ],

                  // Equipments tag list
                  if (equipments.isNotEmpty) ...[
                    Text(
                      'Equipments Available',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildVerticalList(equipments, Colors.orange, theme),
                    const SizedBox(height: 24),
                  ],

                  // Discount & Coupon Section
                  if (!_couponsLoading && _coupons.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.local_offer_outlined, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Discounts & Coupons',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 145,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _coupons.length,
                        itemBuilder: (context, idx) {
                          final coupon = _coupons[idx];
                          final code = coupon['code'] ?? '';
                          final description = coupon['description'] ?? '';
                          final minSlots = coupon['minimum_slots_to_be_ordered'] ?? 0;
                          final discountType = coupon['discount_type'] ?? '';
                          final discountValue = (coupon['discount_value'] is num)
                              ? coupon['discount_value'].toDouble()
                              : double.tryParse(coupon['discount_value']?.toString() ?? '0') ?? 0.0;
                          final maxDiscountAmount = (coupon['max_discount_amount'] is num)
                              ? coupon['max_discount_amount'].toDouble()
                              : (coupon['max_discount_amount'] != null ? double.tryParse(coupon['max_discount_amount'].toString()) : null);

                          String discountStr = '';
                          if (discountType == 'percentage') {
                            discountStr = '${discountValue.toStringAsFixed(0)}% OFF';
                          } else {
                            discountStr = '₹${discountValue.toStringAsFixed(0)} OFF';
                          }

                          // Calculate valid days
                          final days = <String>[];
                          if (coupon['mon'] == true) days.add('Mon');
                          if (coupon['tue'] == true) days.add('Tue');
                          if (coupon['wed'] == true) days.add('Wed');
                          if (coupon['thu'] == true) days.add('Thu');
                          if (coupon['fri'] == true) days.add('Fri');
                          if (coupon['sat'] == true) days.add('Sat');
                          if (coupon['sun'] == true) days.add('Sun');

                          String validDaysStr = '';
                          if (days.length == 7) {
                            validDaysStr = 'All Days';
                          } else if (days.length == 5 && !days.contains('Sat') && !days.contains('Sun')) {
                            validDaysStr = 'Weekdays';
                          } else if (days.length == 2 && days.contains('Sat') && days.contains('Sun')) {
                            validDaysStr = 'Weekends';
                          } else if (days.isNotEmpty) {
                            validDaysStr = days.join(', ');
                          }

                          // Format expiry date
                          String expireStr = '';
                          if (coupon['expires_at'] != null && coupon['expires_at'].toString().isNotEmpty) {
                            try {
                              final expDate = DateTime.parse(coupon['expires_at'].toString());
                              final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                              expireStr = '${expDate.day} ${months[expDate.month - 1]} ${expDate.year}';
                            } catch (_) {
                              expireStr = coupon['expires_at'].toString();
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(right: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Colors.green.withValues(alpha: isDark ? 0.6 : 0.8),
                                width: 1.5,
                              ),
                            ),
                            color: isDark ? const Color(0xFF1E2022) : Colors.green.withValues(alpha: 0.03),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Coupon code "$code" copied!'),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                    width: 250,
                                  ),
                                );
                              },
                              child: Container(
                                width: 280,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Top Row: Code Tag + Discount Ribbon
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.local_offer, color: Colors.green, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                code,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Colors.green,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            discountStr,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Description (if present)
                                    if (description.toString().trim().isNotEmpty) ...[
                                      Text(
                                        description.toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],

                                    // Details Chips / Badge Row
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (minSlots > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.filter_none, size: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Min slots: $minSlots',
                                                  style: TextStyle(
                                                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (maxDiscountAmount != null && maxDiscountAmount > 0 && discountType == 'percentage')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.arrow_downward, size: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Max cap: ₹${maxDiscountAmount.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (validDaysStr.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.calendar_today, size: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                                const SizedBox(width: 3),
                                                Text(
                                                  validDaysStr,
                                                  style: TextStyle(
                                                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (expireStr.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.timer_outlined, size: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Till $expireStr',
                                                  style: TextStyle(
                                                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Bottom Copy Hint
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Tap to copy code',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(Icons.copy, size: 10, color: Colors.grey[500]),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Payment & Policies Section
                  Text(
                    'Rules & Booking Policies',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Card 1: Cancellation & Refund Policy
                  _buildPolicyCard(
                    context: context,
                    isDark: isDark,
                    icon: Icons.event_busy_outlined,
                    iconColor: isCancellationActive ? const Color(0xFF10B981) : Colors.red,
                    title: 'Cancellation & Refund Policy',
                    badge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isCancellationActive ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCancellationActive ? 'Cancellation Allowed' : 'Non-Refundable',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCancellationActive ? const Color(0xFF10B981) : Colors.red,
                        ),
                      ),
                    ),
                    items: [
                      if (isCancellationActive) ...[
                        _buildPolicyBullet(
                          title: 'Allowed Window',
                          description: 'Cancellation is allowed up to $cancellationHours hours prior to the session start time.',
                          isDark: isDark,
                        ),
                        _buildPolicyBullet(
                          title: 'Venue Cancellation Fee',
                          description: cancellationFee > 0
                              ? '₹${cancellationFee.toStringAsFixed(2)} per slot will be deducted upon cancellation.'
                              : 'Free cancellation (₹0.00 venue deduction).',
                          isDark: isDark,
                        ),
                        _buildPolicyBullet(
                          title: 'Platform Convenience Fee',
                          description: 'Platform convenience fee (+GST) is strictly non-refundable once booking is confirmed.',
                          isDark: isDark,
                        ),
                        _buildPolicyBullet(
                          title: 'Refund Timeline',
                          description: 'Online refunds are automatically credited back to your original payment source (UPI/Card/Bank) within 5–7 business days.',
                          isDark: isDark,
                        ),
                        _buildPolicyBullet(
                          title: 'Cut-off Rule',
                          description: 'Cancellations requested within $cancellationHours hours of the slot time are locked and 100% non-refundable.',
                          isDark: isDark,
                          highlightColor: Colors.orange,
                          bulletIcon: Icons.warning_amber_rounded,
                        ),
                      ] else ...[
                        _buildPolicyBullet(
                          title: 'Non-Cancellable',
                          description: 'Bookings for this venue are strictly non-cancellable and non-refundable once confirmed.',
                          isDark: isDark,
                        ),
                        _buildPolicyBullet(
                          title: 'Slot Lock',
                          description: 'In case of player no-show or change of schedule, 100% of the booking amount is forfeited.',
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Card 2: Payment Options & Terms
                  _buildPolicyCard(
                    context: context,
                    isDark: isDark,
                    icon: Icons.payments_outlined,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Payment Options & Terms',
                    badge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${[
                          if (isOnlinePayment) 'Online',
                          if (isPartPayment) 'Part Pay',
                          if (isPayAtLocation) 'Pay at Turf',
                        ].length} Modes Available',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    items: [
                      if (isOnlinePayment)
                        _buildPolicyBullet(
                          title: 'Online Full Payment',
                          description: '100% secure advance booking via UPI, Credit/Debit Cards, Net Banking & Wallets powered by Razorpay.',
                          isDark: isDark,
                          bulletIcon: Icons.credit_card,
                        ),
                      if (isPartPayment)
                        _buildPolicyBullet(
                          title: 'Part Payment (Advance Deposit)',
                          description: (partPaymentType == 'percentage')
                              ? 'Pay an advance deposit of ${(partPaymentValue ?? 20.0).toStringAsFixed(0)}% now to reserve the slot. The remaining balance is payable at the turf reception before playing.'
                              : (partPaymentType == 'fixed')
                                  ? 'Pay an advance token of ₹${(partPaymentValue ?? 100.0).toStringAsFixed(2)} now to reserve the slot. The remaining balance is payable at the turf reception before playing.'
                                  : 'Pay a partial deposit now to lock the slot, and pay the remaining balance at the venue counter.',
                          isDark: isDark,
                          bulletIcon: Icons.pie_chart_outline,
                        ),
                      if (isPayAtLocation)
                        _buildPolicyBullet(
                          title: 'Pay at Location',
                          description: 'Reserve your slot online and pay the full amount via Cash or UPI directly at the turf reception before your game begins.',
                          isDark: isDark,
                          bulletIcon: Icons.storefront_outlined,
                        ),
                      _buildPolicyBullet(
                        title: 'Digital Invoices',
                        description: 'Official GST invoice and booking confirmation slips are accessible anytime from your My Bookings tab.',
                        isDark: isDark,
                        bulletIcon: Icons.receipt_long_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Card 3: Booking Rules & Turf Etiquette
                  _buildPolicyCard(
                    context: context,
                    isDark: isDark,
                    icon: Icons.sports_soccer_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Booking Rules & Turf Etiquette',
                    items: [
                      _buildPolicyBullet(
                        title: 'Advance Booking',
                        description: 'Slots can be booked up to $bookingOpenDays days in advance.',
                        isDark: isDark,
                      ),
                      _buildPolicyBullet(
                        title: 'Reporting Time',
                        description: 'Players must report to the venue 10–15 minutes prior to the booked slot for gate entry and warm-up.',
                        isDark: isDark,
                      ),
                      _buildPolicyBullet(
                        title: 'Footwear Guidelines',
                        description: 'Only flat turf shoes, sneakers, or soft rubber studs are permitted. Metal studs, spikes, and bare feet are strictly prohibited to preserve the turf grass.',
                        isDark: isDark,
                        highlightColor: Colors.amber.shade700,
                        bulletIcon: Icons.warning_amber_rounded,
                      ),
                      _buildPolicyBullet(
                        title: 'Slot Extensions',
                        description: 'Playing beyond the booked duration is subject to subsequent slot availability and extra venue fees.',
                        isDark: isDark,
                      ),
                      _buildPolicyBullet(
                        title: 'Ground Etiquette',
                        description: 'No food, smoking, chewing gum, or alcoholic beverages are permitted inside the turf playing arena.',
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Reviews Header with Write a Review Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reviews & Ratings ($_reviewsCount)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (widget.token != null)
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => ReviewDialog(onSubmit: _submitReview),
                            );
                          },
                          icon: const Icon(Icons.rate_review_outlined, size: 16),
                          label: const Text('Write Review', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_reviewsLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_reviews.isEmpty)
                    Card(
                      elevation: 0,
                      color: isDark ? const Color(0xFF1E2022) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!, width: 1.2),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.rate_review, color: Colors.grey, size: 36),
                              SizedBox(height: 8),
                              Text(
                                'No reviews yet',
                                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Be the first to rate your experience!',
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _reviews.map((rev) {
                        final rRating = rev['rating'] ?? 5;
                        final rUserName = rev['user_name'] ?? 'Anonymous';
                        final rComment = rev['comment'] ?? '';
                        final rDate = rev['created_at'] ?? 'Just now';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          color: isDark ? const Color(0xFF1E2022) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!, width: 1.2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rUserName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      rDate,
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < rRating ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 14,
                                    );
                                  }),
                                ),
                                if (rComment.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    rComment,
                                    style: const TextStyle(fontSize: 13, height: 1.4),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  
                  const SizedBox(height: 100), // safe space for sticky bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price starts from', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    price,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final result = await navigator.push(
                    MaterialPageRoute(
                      builder: (context) => TurfBookingScreen(
                        turf: widget.turf,
                        token: widget.token,
                      ),
                    ),
                  );
                  if ((result == 'show_bookings' || result == 'show_client_bookings') && mounted) {
                    navigator.pop(result);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildVerticalList(List<dynamic> items, Color color, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final String name = (item is Map) ? (item['name']?.toString() ?? '') : item.toString();
        final String? iconVal = (item is Map) ? item['icon']?.toString() : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: DbIconWidget(
                  item: item,
                  explicitIcon: iconVal,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _launchNavigation(double? lat, double? lng, String address) async {
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      final query = Uri.encodeComponent(address);
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Could not launch maps: $e');
    }
  }

  Future<void> _callTurf(String rawPhone) async {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
    final callUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        await Clipboard.setData(ClipboardData(text: cleanPhone));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Phone number $cleanPhone copied to clipboard.')),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Could not launch call: $e');
    }
  }

  Future<void> _messageWhatsApp(String rawPhone, String turfName) async {
    String formattedPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.length == 10) {
      formattedPhone = "91$formattedPhone";
    }
    final message = "Hi, I am inquiring about $turfName via TurfBooking app.";
    final uri = Uri.parse("https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Could not launch WhatsApp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open WhatsApp on this device.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildPolicyCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? badge,
    required List<Widget> items,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2022) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              ?badge,
            ],
          ),
          const SizedBox(height: 14),
          ...items,
        ],
      ),
    );
  }

  Widget _buildPolicyBullet({
    required String title,
    required String description,
    required bool isDark,
    IconData? bulletIcon,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 10),
            child: Icon(
              bulletIcon ?? Icons.circle,
              size: bulletIcon != null ? 14 : 6,
              color: highlightColor ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
