import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/booking_type.dart';
import '../models/turf.dart';

class OrderPreviewScreen extends StatefulWidget {
  final Turf turf;
  final String token;
  final List<int> selectedSlotIds;
  final List<dynamic> selectedSlots;
  final BookingType bookingType;
  final List<String> dates;

  const OrderPreviewScreen({
    super.key,
    required this.turf,
    required this.token,
    required this.selectedSlotIds,
    required this.selectedSlots,
    required this.bookingType,
    required this.dates,
  });

  @override
  State<OrderPreviewScreen> createState() => _OrderPreviewScreenState();
}

class _OrderPreviewScreenState extends State<OrderPreviewScreen> {
  late Razorpay _razorpay;

  // Configuration
  String? _razorpayKey;
  bool _configLoading = true;

  // Preview & Coupon state
  bool _previewLoading = true;
  Map<String, dynamic>? _previewData;
  final Map<String, String> _dateCoupons = {};
  final Map<String, TextEditingController> _couponControllers = {};
  final Map<String, String?> _couponErrors = {};
  final TextEditingController _topCouponController = TextEditingController();

  // User Profile
  String _userName = '';
  String _userEmail = '';
  String _userMobile = '';
  List<String> _userRoles = [];
  List<String> _manageableTurfIds = [];

  // Payment Selection
  String _paymentMethod = 'offline';
  bool _submittingBooking = false;

  // Book on behalf (manager)
  bool _bookOnBehalf = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountReceivedController = TextEditingController();
  final TextEditingController _additionalDiscountController = TextEditingController();
  bool _searchingCustomers = false;
  List<dynamic> _searchedCustomers = [];
  Map<String, dynamic>? _selectedCustomer;
  double _amountReceived = 0.0;
  double _additionalDiscount = 0.0;
  bool _hasSearchedCustomers = false;
  Timer? _debounceTimer;

  // B2B Corporate Invoicing (Optional)
  bool _wantsTaxInvoice = false;
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    
    // Initialize date coupon controllers
    for (final date in widget.dates) {
      _couponControllers[date] = TextEditingController();
      _couponErrors[date] = null;
    }

    _amountReceivedController.addListener(() {
      final text = _amountReceivedController.text;
      setState(() {
        _amountReceived = double.tryParse(text) ?? 0.0;
      });
    });

    _additionalDiscountController.addListener(() {
      final text = _additionalDiscountController.text.trim();
      final double? parsed = double.tryParse(text);
      final double newDiscount = (parsed != null && parsed >= 0) ? parsed : 0.0;
      if (newDiscount != _additionalDiscount) {
        setState(() {
          _additionalDiscount = newDiscount;
        });
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 350), () {
          _fetchPreview(showFullLoader: false);
        });
      }
    });

    _fetchConfig();
    _loadUserProfile();
    
    final bool isOnlinePayment = widget.turf.isOnlinePaymentActive;
    final bool isPartPayment = widget.turf.isPartPaymentActive;

    if (isOnlinePayment) {
      _paymentMethod = 'razorpay_full';
    } else if (isPartPayment) {
      _paymentMethod = 'razorpay_part';
    } else {
      _paymentMethod = 'offline';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _razorpay.clear();
    _searchController.dispose();
    _amountReceivedController.dispose();
    _additionalDiscountController.dispose();
    _topCouponController.dispose();
    _gstinController.dispose();
    _companyNameController.dispose();
    for (final controller in _couponControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchConfig() async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiClient.baseUrl}/config'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _razorpayKey = data['razorpay_key'];
          _configLoading = false;
        });
      } else {
        setState(() => _configLoading = false);
      }
    } catch (e) {
      setState(() => _configLoading = false);
    }
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _userEmail = prefs.getString('user_email') ?? '';
      _userMobile = prefs.getString('user_mobile') ?? '';
      _userRoles = prefs.getStringList('user_roles') ?? [];
      _manageableTurfIds = prefs.getStringList('manageable_turf_ids') ?? [];
    });
    _fetchPreview(showFullLoader: true);
  }

  Future<void> _fetchPreview({bool showFullLoader = false}) async {
    if (showFullLoader || _previewData == null) {
      setState(() {
        _previewLoading = true;
      });
    }

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/turfs/${widget.turf.id}/bookings/preview'),
        headers: ApiClient.authHeaders(widget.token),
        body: jsonEncode({
          'slot_ids': widget.selectedSlotIds,
          'booking_dates': widget.dates,
          'booking_type': widget.bookingType.name,
          'coupons': _dateCoupons,
          if (_bookOnBehalf && _additionalDiscount > 0) 'additional_discount': _additionalDiscount,
          'payment_method': (_paymentMethod == 'razorpay_full' || _paymentMethod == 'razorpay_part') ? 'App' : 'offline',
          'payment_option': (_paymentMethod == 'razorpay_part') ? 'part' : 'full',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _previewData = data;
            _previewLoading = false;

            final bool liveOnline = data['is_online_payment_active'] == true || data['is_online_payment_active'] == 1 || data['is_online_payment_active'] == '1';
            final bool livePart = data['is_part_payment_active'] == true || data['is_part_payment_active'] == 1 || data['is_part_payment_active'] == '1';
            final bool livePayAtLocation = data['is_pay_at_location_active'] == null ? true : (data['is_pay_at_location_active'] == true || data['is_pay_at_location_active'] == 1 || data['is_pay_at_location_active'] == '1');

            if (_paymentMethod == 'razorpay_full' && !liveOnline) {
              _paymentMethod = livePart ? 'razorpay_part' : (livePayAtLocation ? 'offline' : 'offline');
            } else if (_paymentMethod == 'razorpay_part' && !livePart) {
              _paymentMethod = liveOnline ? 'razorpay_full' : (livePayAtLocation ? 'offline' : 'offline');
            } else if (_paymentMethod == 'offline' && !livePayAtLocation) {
              _paymentMethod = liveOnline ? 'razorpay_full' : (livePart ? 'razorpay_part' : 'offline');
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _previewLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _previewLoading = false;
        });
      }
      debugPrint('Error fetching preview: $e');
    }
  }



  void _removeCouponForDate(String date) async {
    setState(() {
      _dateCoupons.remove(date);
      if (_couponControllers[date] != null) {
        _couponControllers[date]!.clear();
      }
      _couponErrors[date] = null;
    });
    await _fetchPreview();
  }

  Future<void> _applyTopCoupon(String code) async {
    if (code.isEmpty) return;

    setState(() {
      for (final date in widget.dates) {
        _dateCoupons[date] = code;
        _couponErrors[date] = null;
      }
    });

    await _fetchPreview();

    if (_previewData != null) {
      final List datesList = _previewData!['dates'] ?? [];
      int successCount = 0;
      int failCount = 0;
      String? firstErrorMessage;

      setState(() {
        for (final dateData in datesList) {
          final String dateStr = dateData['date'] ?? '';
          final coupon = dateData['coupon'];
          if (coupon != null) {
            if (coupon['applied'] == true) {
              _dateCoupons[dateStr] = coupon['code'];
              successCount++;
            } else {
              _dateCoupons.remove(dateStr);
              _couponErrors[dateStr] = coupon['error'];
              firstErrorMessage ??= coupon['error']?.toString();
              failCount++;
            }
          }
        }
      });

      if (!mounted) return;

      if (successCount > 0) {
        _topCouponController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coupon "$code" applied successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (failCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(firstErrorMessage ?? 'Failed to apply coupon "$code".'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach server to apply coupon. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchCustomers(String query) async {
    if (query.trim().length < 2) return;
    setState(() {
      _searchingCustomers = true;
      _searchedCustomers = [];
      _hasSearchedCustomers = false;
    });

    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/users/search?query=${Uri.encodeComponent(query)}'),
        headers: ApiClient.authHeaders(widget.token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _searchedCustomers = data;
          _searchingCustomers = false;
          _hasSearchedCustomers = true;
        });
      } else {
        setState(() {
          _searchingCustomers = false;
          _hasSearchedCustomers = true;
        });
      }
    } catch (e) {
      setState(() {
        _searchingCustomers = false;
        _hasSearchedCustomers = true;
      });
      debugPrint('Error searching customers: $e');
    }
  }

  Future<void> _quickCreateCustomer(String name, String email, String mobile) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/users/quick-create'),
        headers: ApiClient.authHeaders(widget.token),
        body: jsonEncode({
          'name': name,
          'email': email.isNotEmpty ? email : null,
          'mobile': mobile.isNotEmpty ? mobile : null,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (mounted) {
          setState(() {
            _selectedCustomer = data;
            _searchController.clear();
            _searchedCustomers = [];
            _hasSearchedCustomers = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer created and selected successfully.')),
          );
        }
      } else {
        final msg = data['message'] ?? 'Failed to create customer.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating customer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred while creating customer.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateCustomerDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();

    // Autofill the search input into email or mobile if it looks like one!
    final searchInput = _searchController.text.trim();
    if (searchInput.contains('@')) {
      emailCtrl.text = searchInput;
    } else if (RegExp(r'^\d+$').hasMatch(searchInput)) {
      mobileCtrl.text = searchInput;
    } else {
      nameCtrl.text = searchInput;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create New Customer', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'Enter name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: 'Enter mobile number',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'Enter email address',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '* Either Mobile or Email is required.',
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final mobile = mobileCtrl.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Name is required.')),
                  );
                  return;
                }
                if (email.isEmpty && mobile.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Either Mobile or Email is required.')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                _quickCreateCustomer(name, email, mobile);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // Pricing calculations
  double get _subtotal {
    if (_previewData != null) {
      return (_previewData!['subtotal'] as num).toDouble();
    }
    double totalSlotsPrice = 0.0;
    for (var slot in widget.selectedSlots) {
      final priceVal = slot['price'];
      if (priceVal != null) {
        totalSlotsPrice += priceVal is double ? priceVal : double.parse(priceVal.toString());
      }
    }
    return totalSlotsPrice * widget.dates.length;
  }

  double get _couponDiscount {
    if (_previewData != null && _previewData!['coupon_discount'] != null) {
      return (_previewData!['coupon_discount'] as num).toDouble();
    }
    return 0.0;
  }

  double get _additionalDiscountVal {
    if (_previewData != null && _previewData!['additional_discount'] != null) {
      return (_previewData!['additional_discount'] as num).toDouble();
    }
    return _bookOnBehalf ? _additionalDiscount : 0.0;
  }

  double get _turfGstAmount {
    if (_previewData != null && _previewData!['turf_gst_amount'] != null) {
      return (_previewData!['turf_gst_amount'] as num).toDouble();
    }
    return 0.0;
  }

  double get _turfGstRate {
    if (_previewData != null && _previewData!['turf_gst_rate'] != null) {
      return (_previewData!['turf_gst_rate'] as num).toDouble();
    }
    return 0.0;
  }

  String get _turfGstType {
    if (_previewData != null && _previewData!['turf_gst_type'] != null) {
      return _previewData!['turf_gst_type'].toString();
    }
    return 'exempt';
  }

  double get _platformFee {
    if (_previewData != null && _previewData!['platform_fee'] != null) {
      return (_previewData!['platform_fee'] as num).toDouble();
    }
    return 0.0;
  }

  double get _platformFeeGst {
    if (_previewData != null && _previewData!['platform_fee_gst'] != null) {
      return (_previewData!['platform_fee_gst'] as num).toDouble();
    }
    return 0.0;
  }

  bool get _isCancellationActive => _previewData != null && (_previewData!['is_cancellation_active'] == true || _previewData!['is_cancellation_active'] == 1);
  int get _cancellationHours => _previewData != null && _previewData!['cancellation_hours'] != null ? (_previewData!['cancellation_hours'] as num).toInt() : 0;
  double get _cancellationTurfFee => _previewData != null && _previewData!['cancellation_turf_fee'] != null ? (_previewData!['cancellation_turf_fee'] as num).toDouble() : 0.0;
  double get _estimatedRefundAmount => _previewData != null && _previewData!['estimated_refund_amount'] != null ? (_previewData!['estimated_refund_amount'] as num).toDouble() : 0.0;

  double get _totalToPay {
    if (_previewData != null) {
      return (_previewData!['total_amount'] as num).toDouble();
    }
    return _subtotal;
  }

  double get _payableNowAmount {
    if (_bookOnBehalf && _selectedCustomer != null) {
      return _amountReceived;
    }
    if (_previewData != null) {
      if (_paymentMethod == 'razorpay_part') {
        return (_previewData!['payable_now'] as num).toDouble();
      } else if (_paymentMethod == 'offline') {
        return 0.0;
      }
      return _totalToPay;
    }
    return _totalToPay;
  }

  double get _remainingAmount {
    return _totalToPay - _payableNowAmount;
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _completeBooking(response.paymentId, response.orderId, response.signature);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _submittingBooking = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? "Unknown Error"}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
  }

  Future<void> _processBookingFlow() async {
    if (_submittingBooking) return;

    if (_bookOnBehalf && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and select a customer first.')),
      );
      return;
    }

    setState(() {
      _submittingBooking = true;
    });

    if (!_bookOnBehalf && (_paymentMethod == 'razorpay_full' || _paymentMethod == 'razorpay_part')) {
      String? razorpayOrderId;
      String keyToUse = _razorpayKey ?? 'rzp_test_5yX1f8e1F8e1F8';

      // Pre-create Razorpay Order via backend
      try {
        final orderRes = await ApiClient.post(
          Uri.parse('${ApiClient.baseUrl}/turfs/${widget.turf.id}/bookings/order'),
          headers: ApiClient.authHeaders(widget.token),
          body: jsonEncode({
            'amount': _payableNowAmount,
            'currency': 'INR',
          }),
        );
        if (orderRes.statusCode == 200) {
          final orderData = jsonDecode(orderRes.body);
          if (orderData['order_id'] != null) {
            razorpayOrderId = orderData['order_id'].toString();
          }
          if (orderData['key'] != null && orderData['key'].toString().isNotEmpty) {
            keyToUse = orderData['key'].toString();
          }
        }
      } catch (e) {
        debugPrint('Could not create Razorpay order: $e');
      }

      final options = {
        'key': keyToUse,
        'amount': (_payableNowAmount * 100).toInt(),
        'name': widget.turf.name.isNotEmpty ? widget.turf.name : 'Turf Booking',
        'description': 'Booking for ${widget.turf.name}',
        if (razorpayOrderId != null && razorpayOrderId.isNotEmpty)
          'order_id': razorpayOrderId,
        'prefill': {
          'contact': _userMobile.isNotEmpty ? _userMobile : '9999999999',
          'email': _userEmail.isNotEmpty ? _userEmail : 'user@example.com',
          'name': _userName.isNotEmpty ? _userName : 'User Name',
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      try {
        _razorpay.open(options);
      } catch (e) {
        if (mounted) {
          setState(() => _submittingBooking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open payment gateway: $e')),
          );
        }
      }
    } else {
      _completeBooking(null);
    }
  }

  Future<void> _completeBooking(String? paymentId, [String? orderId, String? signature]) async {
    final turfId = widget.turf.id;
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final Map<String, String> appliedCoupons = {};
    _dateCoupons.forEach((date, code) {
      if (code.isNotEmpty) {
        appliedCoupons[date] = code;
      }
    });

    final Map<String, dynamic> requestBody = {
      'slot_ids': widget.selectedSlotIds,
      'booking_dates': widget.dates,
      'booking_type': widget.bookingType.name,
      'coupons': appliedCoupons,
    };

    if (_bookOnBehalf && _selectedCustomer != null) {
      requestBody['customer_id'] = _selectedCustomer!['id'];
      requestBody['payment_method'] = _paymentMethod;
      requestBody['amount_received'] = _amountReceived;
      if (_additionalDiscount > 0) {
        requestBody['additional_discount'] = _additionalDiscount;
      }
    } else {
      requestBody['payment_method'] = (_paymentMethod == 'razorpay_full' || _paymentMethod == 'razorpay_part') ? 'App' : 'offline';
      requestBody['payment_option'] = _paymentMethod == 'razorpay_part' ? 'part' : 'full';
      requestBody['razorpay_payment_id'] = paymentId;
      if (orderId != null && orderId.isNotEmpty) {
        requestBody['razorpay_order_id'] = orderId;
      }
      if (signature != null && signature.isNotEmpty) {
        requestBody['razorpay_signature'] = signature;
      }
    }

    if (_wantsTaxInvoice && _gstinController.text.trim().isNotEmpty) {
      requestBody['customer_gstin'] = _gstinController.text.trim().toUpperCase();
      if (_companyNameController.text.trim().isNotEmpty) {
        requestBody['customer_company_name'] = _companyNameController.text.trim();
      }
    }

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/turfs/$turfId/bookings'),
        headers: ApiClient.authHeaders(widget.token),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        setState(() => _submittingBooking = false);
        if (!mounted) return;
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Booking Confirmed'),
              ],
            ),
            content: Text(
              _bookOnBehalf && _selectedCustomer != null
                  ? 'Booking for ${_selectedCustomer!['name']} is confirmed! Initial payment of ₹${_amountReceived.toStringAsFixed(2)} recorded.'
                  : _paymentMethod == 'razorpay_full'
                      ? 'Your payment was successful and booking is confirmed!'
                      : _paymentMethod == 'razorpay_part'
                          ? 'Your deposit payment was successful and booking is confirmed! Please pay the remaining balance at the venue.'
                          : 'Your booking is confirmed! Please pay at the location.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        if (_bookOnBehalf) {
          navigator.pop('show_client_bookings');
        } else {
          navigator.pop('show_bookings');
        }
      } else {
        final errorMsg = jsonDecode(response.body)['message'] ?? 'Booking failed. Please try again.';
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
        setState(() => _submittingBooking = false);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.red));
      setState(() => _submittingBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bool isPayAtLocation = (_previewData != null && _previewData!['is_pay_at_location_active'] != null)
        ? (_previewData!['is_pay_at_location_active'] == true || _previewData!['is_pay_at_location_active'] == 1 || _previewData!['is_pay_at_location_active'] == '1')
        : (widget.turf.isPayAtLocationActive ?? true);
    final bool isOnlinePayment = (_previewData != null && _previewData!['is_online_payment_active'] != null)
        ? (_previewData!['is_online_payment_active'] == true || _previewData!['is_online_payment_active'] == 1 || _previewData!['is_online_payment_active'] == '1')
        : widget.turf.isOnlinePaymentActive;
    final bool isPartPayment = (_previewData != null && _previewData!['is_part_payment_active'] != null)
        ? (_previewData!['is_part_payment_active'] == true || _previewData!['is_part_payment_active'] == 1 || _previewData!['is_part_payment_active'] == '1')
        : widget.turf.isPartPaymentActive;

    final String turfId = widget.turf.id.toString();
    final bool isManagerOrAdmin = _userRoles.any((r) => ['turf-admin', 'manager'].contains(r)) &&
        _manageableTurfIds.contains(turfId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Preview'),
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: (_configLoading || (_previewLoading && _previewData == null))
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              // Bottom padding also clears the device's system nav bar / gesture bar, so
              // the "Pay & Confirm" button at the end of this scroll view isn't hidden under it.
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Turf summary card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          if (widget.turf.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.turf.imageUrl!,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.turf.name.isNotEmpty ? widget.turf.name : 'Turf',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        widget.turf.locationAddress,
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${widget.bookingType.name.toUpperCase()} BOOKING',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Admin / Manager book on behalf section
                  if (isManagerOrAdmin) ...[
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.admin_panel_settings, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  'Owner / Manager Dashboard',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            SwitchListTile(
                              title: const Text('Book on behalf of Customer'),
                              subtitle: const Text('Select another user to associate this booking with'),
                              value: _bookOnBehalf,
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor: theme.colorScheme.primary,
                              onChanged: (val) {
                                setState(() {
                                  _bookOnBehalf = val;
                                  if (!val) {
                                    _selectedCustomer = null;
                                    _searchController.clear();
                                    _searchedCustomers = [];
                                    _amountReceivedController.clear();
                                    _amountReceived = 0.0;
                                    _paymentMethod = 'offline';
                                  } else {
                                    _paymentMethod = 'Cash'; // Default offline method for manager
                                  }
                                });
                              },
                            ),
                            if (_bookOnBehalf) ...[
                              const SizedBox(height: 12),
                              if (_selectedCustomer == null) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          hintText: 'Search customer by Name, Email, Mobile',
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () => _searchCustomers(_searchController.text),
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Search'),
                                    ),
                                  ],
                                ),
                                if (_searchingCustomers)
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                if (_searchedCustomers.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    constraints: const BoxConstraints(maxHeight: 150),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _searchedCustomers.length,
                                      itemBuilder: (context, index) {
                                        final c = _searchedCustomers[index];
                                        return ListTile(
                                          title: Text(c['name'] ?? ''),
                                          subtitle: Text('${c['mobile'] ?? ''} | ${c['email'] ?? ''}'),
                                          onTap: () {
                                            setState(() {
                                              _selectedCustomer = c;
                                              _searchedCustomers = [];
                                              _searchController.clear();
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                if (_searchedCustomers.isEmpty && _hasSearchedCustomers && !_searchingCustomers)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'No customer found.',
                                          style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                                        ),
                                        TextButton.icon(
                                          onPressed: _showCreateCustomerDialog,
                                          icon: const Icon(Icons.person_add, size: 16),
                                          label: const Text(
                                            'Create New Customer',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Customer: ${_selectedCustomer!['name']}',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_selectedCustomer!['mobile']} | ${_selectedCustomer!['email']}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _selectedCustomer = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Payment Method (Offline)',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: ['Cash', 'UPI', 'Other'].map((method) {
                                    return Expanded(
                                      // ignore: deprecated_member_use
                                      child: RadioListTile<String>(
                                        title: Text(method, style: const TextStyle(fontSize: 12)),
                                        value: method,
                                        // ignore: deprecated_member_use
                                        groupValue: _paymentMethod,
                                        contentPadding: EdgeInsets.zero,
                                        activeColor: theme.colorScheme.primary,
                                        // ignore: deprecated_member_use
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _paymentMethod = val;
                                            });
                                          }
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _additionalDiscountController,
                                  decoration: InputDecoration(
                                    labelText: 'Additional Discount (₹)',
                                    hintText: 'Enter manual discount amount (if any)',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _amountReceivedController,
                                  decoration: InputDecoration(
                                    labelText: 'Amount Received (₹)',
                                    hintText: 'Enter amount collected now',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Top Coupon Code Input Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_offer, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Apply Coupon Code',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _topCouponController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter coupon code',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  textCapitalization: TextCapitalization.characters,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  final code = _topCouponController.text.trim().toUpperCase();
                                  _applyTopCoupon(code);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Apply'),
                              ),
                            ],
                          ),
                          if (_couponDiscount > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Coupon applied! You saved ₹${_couponDiscount.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      for (final d in widget.dates) {
                                        _removeCouponForDate(d);
                                      }
                                    },
                                    child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Session detail list with date-wise coupons
                  Text(
                    'Booking Dates & Slots',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...?_previewData?['dates']?.map<Widget>((dateData) {
                    final String dateStr = dateData['date'] ?? '';
                    final String dayLabel = dateData['day_name'] ?? '';
                    final List slotsList = dateData['slots'] ?? [];
                    final dateDiscount = (dateData['discount'] ?? dateData['coupon_discount'] ?? 0.0) is num
                        ? (dateData['discount'] ?? dateData['coupon_discount'] ?? 0.0).toDouble()
                        : double.tryParse((dateData['discount'] ?? dateData['coupon_discount'] ?? '0').toString()) ?? 0.0;
                    final dateNet = (dateData['net_amount'] ?? dateData['turf_total'] ?? dateData['subtotal'] ?? 0.0) is num
                        ? (dateData['net_amount'] ?? dateData['turf_total'] ?? dateData['subtotal'] ?? 0.0).toDouble()
                        : double.tryParse((dateData['net_amount'] ?? dateData['turf_total'] ?? '0').toString()) ?? 0.0;

                    final couponApplied = dateData['coupon'] != null && dateData['coupon']['applied'] == true;
                    final couponError = dateData['coupon'] != null ? dateData['coupon']['error'] as String? : null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$dayLabel, $dateStr',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '₹${dateNet.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Slots booked on this date
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: slotsList.length,
                              itemBuilder: (context, idx) {
                                final s = slotsList[idx];
                                final isBooked = s['status'] == 'booked';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isBooked ? Icons.lock : Icons.check_circle_outline,
                                            size: 14,
                                            color: isBooked ? Colors.red : Colors.green,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            s['time_label'] ?? '',
                                            style: TextStyle(
                                              decoration: isBooked ? TextDecoration.lineThrough : null,
                                              color: isBooked ? Colors.grey : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        isBooked
                                            ? 'Unavailable (No Charge)'
                                            : '₹${(s['price'] as num).toDouble().toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: isBooked ? FontWeight.normal : FontWeight.bold,
                                          color: isBooked ? Colors.red : null,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Date-wise Coupon status/display
                            if (couponApplied) ...[
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.local_offer, color: Colors.green, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Coupon applied: ${dateData['coupon']['code']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '-₹${dateDiscount.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton(
                                        onPressed: () => _removeCouponForDate(dateStr),
                                        child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ] else if ((couponError ?? _couponErrors[dateStr]) != null) ...[
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            couponError ?? _couponErrors[dateStr]!,
                                            style: const TextStyle(color: Colors.red, fontSize: 12),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _couponErrors[dateStr] = null;
                                      });
                                    },
                                    child: const Text('Clear', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 16),

                  // Customer Payment Options (only visible if not manager booking for someone else)
                  if (!_bookOnBehalf) ...[
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.payment, size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text(
                                  'Payment Method',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            if (isOnlinePayment)
                              // ignore: deprecated_member_use
                              RadioListTile<String>(
                                title: const Text('Pay Online'),
                                subtitle: const Text('Pay full amount securely via Credit Card, Netbanking, or UPI'),
                                value: 'razorpay_full',
                                // ignore: deprecated_member_use
                                groupValue: _paymentMethod,
                                // ignore: deprecated_member_use
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _paymentMethod = val);
                                    _fetchPreview(showFullLoader: false);
                                  }
                                },
                                activeColor: theme.colorScheme.primary,
                                contentPadding: EdgeInsets.zero,
                              ),
                            if (isPartPayment)
                              // ignore: deprecated_member_use
                              RadioListTile<String>(
                                title: const Text('Part Payment'),
                                subtitle: const Text('Accepts part payment online, remaining will be taken at the turf'),
                                value: 'razorpay_part',
                                // ignore: deprecated_member_use
                                groupValue: _paymentMethod,
                                // ignore: deprecated_member_use
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _paymentMethod = val);
                                    _fetchPreview(showFullLoader: false);
                                  }
                                },
                                activeColor: theme.colorScheme.primary,
                                contentPadding: EdgeInsets.zero,
                              ),
                            if (isPayAtLocation)
                              // ignore: deprecated_member_use
                              RadioListTile<String>(
                                title: const Text('Pay at Location'),
                                subtitle: const Text('Full payment will be paid at location'),
                                value: 'offline',
                                // ignore: deprecated_member_use
                                groupValue: _paymentMethod,
                                // ignore: deprecated_member_use
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _paymentMethod = val);
                                    _fetchPreview(showFullLoader: false);
                                  }
                                },
                                activeColor: theme.colorScheme.primary,
                                contentPadding: EdgeInsets.zero,
                              ),
                            if (!isPayAtLocation && !isOnlinePayment && !isPartPayment)
                              // ignore: deprecated_member_use
                              RadioListTile<String>(
                                title: const Text('Pay at Location'),
                                subtitle: const Text('Full payment will be paid at location'),
                                value: 'offline',
                                // ignore: deprecated_member_use
                                groupValue: _paymentMethod,
                                // ignore: deprecated_member_use
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _paymentMethod = val);
                                    _fetchPreview(showFullLoader: false);
                                  }
                                },
                                activeColor: theme.colorScheme.primary,
                                contentPadding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Optional B2B GSTIN Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Add GSTIN for Business Invoicing',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: _wantsTaxInvoice,
                                activeTrackColor: theme.colorScheme.primary,
                                onChanged: (val) {
                                  setState(() => _wantsTaxInvoice = val);
                                },
                              ),
                            ],
                          ),
                          if (_wantsTaxInvoice) ...[
                            const Divider(height: 16),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _gstinController,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 15,
                              decoration: InputDecoration(
                                labelText: 'GSTIN (15 Digits)',
                                hintText: 'e.g. 27AAAAA0000A1Z5',
                                counterText: '',
                                prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _companyNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'Company / Firm Name',
                                hintText: 'e.g. Acme Sports Club Pvt Ltd',
                                prefixIcon: const Icon(Icons.business_outlined, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pricing details card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Slot Subtotal', style: TextStyle(color: Colors.grey)),
                              Text('₹${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                          if (_couponDiscount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Coupon Discount', style: TextStyle(color: Colors.green)),
                                Text('-₹${_couponDiscount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                          if (_additionalDiscountVal > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Additional Discount', style: TextStyle(color: Colors.teal)),
                                Text('-₹${_additionalDiscountVal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                          if (_turfGstAmount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _turfGstType == 'included'
                                      ? 'Turf GST (${_turfGstRate.toStringAsFixed(0)}% incl.)'
                                      : 'Turf GST (${_turfGstRate.toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                    color: _turfGstType == 'included' ? Colors.grey : theme.textTheme.bodyMedium?.color,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  _turfGstType == 'included'
                                      ? '₹${_turfGstAmount.toStringAsFixed(2)}'
                                      : '+₹${_turfGstAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: _turfGstType == 'included' ? Colors.grey : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_platformFee > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Platform Fee (incl. GST)',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                Text(
                                  '+₹${(_platformFee + _platformFeeGst).toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(
                                '₹${_totalToPay.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          if (_bookOnBehalf || _paymentMethod == 'razorpay_part' || _paymentMethod == 'offline') ...[
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _bookOnBehalf
                                      ? 'Collected Amount'
                                      : _paymentMethod == 'offline'
                                          ? 'Payable Now'
                                          : 'Payable Now (Online Deposit)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.primary),
                                ),
                                Text(
                                  '₹${_payableNowAmount.toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Remaining Balance',
                                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '₹${_remainingAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Upfront Cancellation Policy Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isCancellationActive
                          ? Colors.teal.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isCancellationActive
                            ? Colors.teal.withValues(alpha: 0.25)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isCancellationActive ? Icons.shield_outlined : Icons.info_outline,
                          size: 18,
                          color: _isCancellationActive ? Colors.teal : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isCancellationActive
                                    ? 'Cancellation Policy (Up to $_cancellationHours hrs prior)'
                                    : 'Cancellation Policy',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isCancellationActive ? Colors.teal : Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isCancellationActive
                                    ? 'Turf fee: ₹${_cancellationTurfFee.toStringAsFixed(2)} • Estimated Refund: ₹${_estimatedRefundAmount.toStringAsFixed(2)}'
                                    : 'Venue cancellation is non-refundable once confirmed.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submittingBooking ? null : _processBookingFlow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _submittingBooking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _bookOnBehalf
                                  ? 'Record & Confirm Booking'
                                  : (_paymentMethod == 'razorpay_full' || _paymentMethod == 'razorpay_part')
                                      ? 'Pay & Confirm'
                                      : 'Confirm Booking',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
