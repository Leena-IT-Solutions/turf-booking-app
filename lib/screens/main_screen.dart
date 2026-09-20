import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/snackbar_helper.dart';
import '../models/booking.dart';
import '../models/turf.dart';
import 'main/bookings_tab.dart';
import 'main/client_bookings_tab.dart';
import 'main/dashboard_tab.dart';
import 'main/home_tab.dart';
import 'main/profile_tab.dart';
import 'main/support_tab.dart';
import 'map_picker_screen.dart';
import 'turf_detail_screen.dart';

class MainScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userMobile;
  final String token;
  final VoidCallback onLogout;
  final Function(String, String, String) onProfileUpdated;

  const MainScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userMobile,
    required this.token,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // 0: Home, 1: Bookings, 2: Support, 3: Profile
  bool _profileLoading = false;
  List<String> _userRoles = [];
  List<String> _manageableTurfIds = [];

  Future<void> _loadUserRoles() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final roles = prefs.getStringList('user_roles') ?? [];
      final manageableTurfs = prefs.getStringList('manageable_turf_ids') ?? [];
      setState(() {
        _userRoles = roles;
        _manageableTurfIds = manageableTurfs;
      });
      final isManagerOrAdmin = roles.any((r) =>
          r == 'turf-admin' || r == 'turf-manager' || r == 'saas-admin' || r == 'admin');
      if (isManagerOrAdmin) {
        _fetchDashboardStats();
      }
    }
  }

  List<dynamic> _supportMessages = [];
  bool _supportLoading = false;
  final TextEditingController _supportMessageController = TextEditingController();
  final ScrollController _supportScrollController = ScrollController();
  final FocusNode _supportFocusNode = FocusNode();
  Timer? _supportTimer;
  bool _showChatWindow = false;
  List<dynamic> _sliderImages = [];
  bool _sliderLoading = false;
  List<Turf> _turfs = [];
  bool _turfsLoading = false;
  PageController? _sliderPageController;
  Timer? _sliderTimer;
  int _sliderCurrentPage = 0;
  String _selectedCity = 'Mumbai';
  bool _isLocating = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  List<Map<String, dynamic>> _suggestions = [];
  bool _suggestionsLoading = false;
  Timer? _debounceTimer;
  String? _googleMapsApiKey;
  int _turfSearchKm = 10;


  List<Booking> _bookings = [];
  bool _bookingsLoading = false;
  String _bookingsFilter = 'upcoming';
  int _bookingsPage = 1;
  bool _hasMoreBookings = true;
  bool _bookingsLoadingMore = false;
  final ScrollController _bookingsScrollController = ScrollController();

  // Client Booking Screen state variables
  DateTime _clientBookingSelectedDate = DateTime.now();
  String _clientBookingFilter = 'upcoming';
  List<Booking> _clientBookings = [];
  bool _clientBookingsLoading = false;

  // Dashboard Screen state variables
  Map<String, dynamic>? _dashboardStats;
  bool _dashboardStatsLoading = false;
  int? _dashboardSelectedTurfId;
  int? _clientBookingSelectedTurfId;
  List<dynamic> _manageableTurfs = [];

  void _showError(String message) => SnackbarHelper.showError(context, message);

  void _showSuccess(String message) => SnackbarHelper.showSuccess(context, message);

  Future<void> _fetchBookings({bool refresh = false, bool loadMore = false}) async {
    if (refresh) {
      if (mounted) {
        setState(() {
          _bookingsPage = 1;
          _hasMoreBookings = true;
        });
      }
    }

    if (loadMore) {
      if (mounted) setState(() => _bookingsLoadingMore = true);
    } else {
      if (mounted) setState(() => _bookingsLoading = true);
    }

    try {
      final pageToFetch = refresh ? 1 : (loadMore ? _bookingsPage + 1 : 1);
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/bookings?page=$pageToFetch&per_page=10&filter=$_bookingsFilter&personal=1'),
        headers: ApiClient.authHeaders(widget.token),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = List<dynamic>.from(data['data'] ?? [])
            .map((j) => Booking.fromJson(j as Map<String, dynamic>))
            .toList();
        final lastPage = data['last_page'] ?? 1;
        final currentPage = data['current_page'] ?? 1;

        if (mounted) {
          setState(() {
            if (refresh || !loadMore) {
              _bookings = list;
              _bookingsPage = 1;
            } else {
              _bookings.addAll(list);
              _bookingsPage = currentPage;
            }
            _hasMoreBookings = currentPage < lastPage;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _bookingsLoading = false;
          _bookingsLoadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchClientBookings() async {
    if (mounted) {
      setState(() {
        _clientBookingsLoading = true;
        _clientBookings = [];
      });
    }

    try {
      final dateStr = "${_clientBookingSelectedDate.year}-${_clientBookingSelectedDate.month.toString().padLeft(2, '0')}-${_clientBookingSelectedDate.day.toString().padLeft(2, '0')}";
      final turfParam = _clientBookingSelectedTurfId != null ? '&turf_id=$_clientBookingSelectedTurfId' : '';
      final filterParam = '&filter=$_clientBookingFilter';
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/bookings?date=$dateStr$filterParam$turfParam'),
        headers: ApiClient.authHeaders(widget.token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          List<Booking> list = List<dynamic>.from(data['data'] ?? [])
              .map((j) => Booking.fromJson(j as Map<String, dynamic>))
              .toList();

          if (_clientBookingFilter == 'upcoming') {
            list = list.where((b) => !b.isPast() && !b.isCancelled).toList();
          } else if (_clientBookingFilter == 'past') {
            list = list.where((b) => b.isPast() && !b.isCancelled).toList();
          } else if (_clientBookingFilter == 'cancelled') {
            list = list.where((b) => b.isCancelled).toList();
          }

          list.sort((a, b) {
            final timeA = a.slots.isNotEmpty ? (a.slots.first.fromTime ?? '') : '';
            final timeB = b.slots.isNotEmpty ? (b.slots.first.fromTime ?? '') : '';
            return timeA.compareTo(timeB);
          });

          setState(() {
            _clientBookings = list;
            _clientBookingsLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _clientBookingsLoading = false);
          _showError('Failed to load client bookings.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _clientBookingsLoading = false);
        _showError('Network error. Failed to load client bookings.');
      }
    }
  }

  Future<void> _cancelBooking(int bookingId, {List<int>? bookingDateIds}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bodyMap = <String, dynamic>{};
      if (bookingDateIds != null && bookingDateIds.isNotEmpty) {
        bodyMap['booking_date_ids'] = bookingDateIds;
      }

      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/bookings/$bookingId/cancel'),
        headers: ApiClient.authHeaders(widget.token),
        body: jsonEncode(bodyMap),
      );

      if (mounted) Navigator.pop(context);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _showSuccess(data['message'] ?? 'Booking cancelled successfully.');
        _fetchBookings(refresh: true);
        _fetchClientBookings();
        _fetchDashboardStats();
      } else {
        _showError(data['message'] ?? 'Failed to cancel booking.');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Network error. Failed to cancel booking.');
    }
  }

  Future<void> _fetchDashboardStats() async {
    final isManagerOrAdmin = _userRoles.any((r) =>
        r == 'turf-admin' || r == 'turf-manager' || r == 'saas-admin' || r == 'admin');
    if (!isManagerOrAdmin) {
      if (mounted) setState(() => _dashboardStatsLoading = false);
      return;
    }

    if (mounted) {
      setState(() {
        _dashboardStatsLoading = true;
      });
    }

    try {
      final queryParam = _dashboardSelectedTurfId != null ? '?turf_id=$_dashboardSelectedTurfId' : '';
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/dashboard/stats$queryParam'),
        headers: ApiClient.authHeaders(widget.token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _dashboardStats = data;
            _dashboardStatsLoading = false;
            _manageableTurfs = List<dynamic>.from(data['turfs'] ?? []);
          });
        }
      } else {
        if (mounted) {
          setState(() => _dashboardStatsLoading = false);
          if (response.statusCode != 403) {
            _showError('Failed to load dashboard stats.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dashboardStatsLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _sliderPageController = PageController(initialPage: 0);
    _bookingsScrollController.addListener(() {
      if (_bookingsScrollController.position.pixels >= _bookingsScrollController.position.maxScrollExtent - 200) {
        if (!_bookingsLoadingMore && _hasMoreBookings && !_bookingsLoading) {
          _fetchBookings(loadMore: true);
        }
      }
    });
    _loadUserRoles();
    _fetchSliderImages();
    _fetchAppConfig();
    _getCurrentLocation();
    _fetchTurfs();
    _fetchBookings();
    _fetchClientBookings();
  }

  void _startSliderTimer() {
    _sliderTimer?.cancel();
    if (_sliderImages.isEmpty) return;
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_sliderPageController != null && _sliderPageController!.hasClients) {
        int nextPage = _sliderCurrentPage + 1;
        if (nextPage >= _sliderImages.length) {
          nextPage = 0;
        }
        _sliderPageController!.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchSliderImages() async {
    if (mounted) setState(() => _sliderLoading = true);
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/slider-images'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _sliderImages = data;
            _sliderLoading = false;
          });
          _startSliderTimer();
        }
      } else {
        if (mounted) setState(() => _sliderLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _sliderLoading = false);
    }
  }

  Future<void> _fetchTurfs() async {
    if (mounted) setState(() => _turfsLoading = true);
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/turfs'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _turfs = data.map((j) => Turf.fromJson(j as Map<String, dynamic>)).toList();
            _turfsLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _turfsLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _turfsLoading = false);
    }
  }

  String _capitalizeCity(String name) {
    if (name.isEmpty) return name;
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Pi / 180
    final double a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  List<Turf> get _filteredTurfs {
    if (_selectedLatitude == null || _selectedLongitude == null) {
      return _turfs;
    }
    return _turfs.where((turf) {
      if (turf.latitude == null || turf.longitude == null) return false;

      final distance = _calculateDistance(
        _selectedLatitude!,
        _selectedLongitude!,
        turf.latitude!,
        turf.longitude!,
      );
      return distance <= _turfSearchKm;
    }).toList();
  }

  Future<void> _fetchAppConfig() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/config'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final apiKey = data['google_maps_api_key'] as String?;
        final searchKm = data['turf_search_km'];
        setState(() {
          if (apiKey != null && apiKey.isNotEmpty) {
            _googleMapsApiKey = apiKey;
          }
          if (searchKm != null) {
            _turfSearchKm = searchKm is int ? searchKm : int.parse(searchKm.toString());
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch App Config: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        _isLocating = true;
      });
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _selectedCity = 'Mumbai';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLocating = false;
              _selectedCity = 'Mumbai';
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _selectedCity = 'Mumbai';
          });
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (timeoutOrError) {
        // Fallback to last known position if current position times out or errors
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (mounted) {
          setState(() {
            _selectedCity = 'Mumbai';
            _isLocating = false;
          });
        }
        return;
      }

      debugPrint('Geolocation success: Lat: ${position.latitude}, Lng: ${position.longitude}');

      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        debugPrint('Geocoding place details: locality=${place.locality}, subAdmin=${place.subAdministrativeArea}, admin=${place.administrativeArea}');
        String? city = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea;
        if (mounted) {
          setState(() {
            _selectedCity = _capitalizeCity((city != null && city.isNotEmpty) ? city : 'Mumbai');
            _selectedLatitude = position!.latitude;
            _selectedLongitude = position.longitude;
            _isLocating = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedCity = 'Mumbai';
            _selectedLatitude = position!.latitude;
            _selectedLongitude = position.longitude;
            _isLocating = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Geolocation error occurred: $e');
      if (mounted) {
        setState(() {
          _selectedCity = 'Mumbai';
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _selectCityAndResolveCoordinates(String cityName) async {
    if (mounted) {
      setState(() {
        _selectedCity = _capitalizeCity(cityName);
        _isLocating = true;
      });
    }
    try {
      List<Location> locations = await Geocoding().locationFromAddress(cityName);
      if (locations.isNotEmpty) {
        Location loc = locations[0];
        debugPrint('Forward geocoding success for $cityName: Lat: ${loc.latitude}, Lng: ${loc.longitude}');
        if (mounted) {
          setState(() {
            _selectedLatitude = loc.latitude;
            _selectedLongitude = loc.longitude;
            _isLocating = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedLatitude = null;
            _selectedLongitude = null;
            _isLocating = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Forward geocoding error: $e');
      if (mounted) {
        setState(() {
          _selectedLatitude = null;
          _selectedLongitude = null;
          _isLocating = false;
        });
      }
    }
  }

  void _onSearchTextChanged(String text, BuildContext dialogContext, StateSetter setDialogState) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    if (text.trim().isEmpty) {
      if (dialogContext.mounted) {
        setDialogState(() {
          _suggestions = [];
          _suggestionsLoading = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!dialogContext.mounted) return;
      setDialogState(() {
        _suggestionsLoading = true;
      });

      try {
        // Appending ', India' to force geocoding suggestions to be biased/located in India
        List<Location> locations = await Geocoding().locationFromAddress("$text, India");
        List<Map<String, dynamic>> resolvedPlaces = [];
        final Set<String> seenDisplayNames = {};
        
        int limit = locations.length > 6 ? 6 : locations.length;
        for (int i = 0; i < limit; i++) {
          if (!dialogContext.mounted) return;
          Location loc = locations[i];
          try {
            List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
              loc.latitude,
              loc.longitude,
            );
            if (placemarks.isNotEmpty) {
              Placemark pm = placemarks[0];
              
              // Validate that the returned placemark is in India
              final isIndia = (pm.country?.toLowerCase() == 'india' || pm.isoCountryCode?.toLowerCase() == 'in');
              if (!isIndia) continue;
              
              final Set<String> uniqueParts = {};
              if (pm.subLocality != null && pm.subLocality!.isNotEmpty) uniqueParts.add(pm.subLocality!);
              if (pm.locality != null && pm.locality!.isNotEmpty) uniqueParts.add(pm.locality!);
              if (pm.subAdministrativeArea != null && pm.subAdministrativeArea!.isNotEmpty) uniqueParts.add(pm.subAdministrativeArea!);
              if (pm.administrativeArea != null && pm.administrativeArea!.isNotEmpty) uniqueParts.add(pm.administrativeArea!);
              
              String displayName = uniqueParts.isNotEmpty ? uniqueParts.join(', ') : text;
              displayName = _capitalizeCity(displayName);
              
              if (seenDisplayNames.contains(displayName.toLowerCase())) continue;
              seenDisplayNames.add(displayName.toLowerCase());
              
              String city = pm.locality ?? pm.subLocality ?? pm.name ?? text;
              
              resolvedPlaces.add({
                'name': displayName,
                'city': city,
                'lat': loc.latitude,
                'lng': loc.longitude,
              });
            }
          } catch (e) {
            // Ignore error for individual placemark resolution
          }
        }

        if (dialogContext.mounted) {
          setDialogState(() {
            _suggestions = resolvedPlaces;
            _suggestionsLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Suggestions error: $e');
        if (dialogContext.mounted) {
          setDialogState(() {
            _suggestions = [];
            _suggestionsLoading = false;
          });
        }
      }
    });
  }

  void _showCityPickerDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final List<String> popularCities = [
      'Mumbai',
      'Navi Mumbai',
      'Thane',
      'Pune',
      'Delhi',
      'Bangalore',
      'Hyderabad',
      'Chennai'
    ];
    final Map<String, String> cityCoordinates = {
      'Mumbai': '19.0760° N, 72.8777° E',
      'Navi Mumbai': '19.0330° N, 73.0297° E',
      'Thane': '19.2183° N, 72.9781° E',
      'Pune': '18.5204° N, 73.8567° E',
      'Delhi': '28.6139° N, 77.2090° E',
      'Bangalore': '12.9716° N, 77.5946° E',
      'Hyderabad': '17.3850° N, 78.4867° E',
      'Chennai': '13.0827° N, 80.2707° E'
    };
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            _debounceTimer?.cancel();
          },
          child: StatefulBuilder(
            builder: (context, setDialogState) {
            final filteredCities = popularCities
                .where((city) => city.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E2022) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            if (_selectedLatitude != null && _selectedLongitude != null) ...[
                              const SizedBox(height: 2),
                              InkWell(
                                onTap: () {
                                  final coords = '${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}';
                                  Clipboard.setData(ClipboardData(text: coords));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied coordinates: $coords'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Text(
                                  '${_selectedLatitude!.toStringAsFixed(4)}°, ${_selectedLongitude!.toStringAsFixed(4)}°',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search city...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        fillColor: isDark ? const Color(0xFF0F1011) : Colors.grey[100],
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                        _onSearchTextChanged(val, context, setDialogState);
                      },
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _selectCityAndResolveCoordinates(val.trim());
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Detect Location & Set on Map Buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _getCurrentLocation();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.my_location_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Current Location',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              Navigator.pop(context);
                              debugPrint('Launching map picker. Configured key: $_googleMapsApiKey');
                              // Launch Map Picker Screen
                              final LatLng? result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapPickerScreen(
                                    initialLatitude: _selectedLatitude ?? 19.0760,
                                    initialLongitude: _selectedLongitude ?? 72.8777,
                                  ),
                                ),
                              );
                              if (result != null) {
                                // Reverse geocode the picked coordinate and update state
                                if (mounted) {
                                  setState(() {
                                    _isLocating = true;
                                  });
                                }
                                try {
                                  List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
                                    result.latitude,
                                    result.longitude,
                                  );
                                  String city = 'Mumbai';
                                  if (placemarks.isNotEmpty) {
                                    final pm = placemarks[0];
                                    city = pm.locality ?? pm.subLocality ?? pm.name ?? 'Mumbai';
                                    city = _capitalizeCity(city);
                                  }
                                  
                                  // Save selected coordinates & city
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('selected_city', city);
                                  await prefs.setDouble('selected_latitude', result.latitude);
                                  await prefs.setDouble('selected_longitude', result.longitude);
                                  
                                  if (mounted) {
                                    setState(() {
                                      _selectedCity = city;
                                      _selectedLatitude = result.latitude;
                                      _selectedLongitude = result.longitude;
                                      _isLocating = false;
                                    });
                                    _showSuccess('Location updated to $city');
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _isLocating = false;
                                    });
                                  }
                                  _showError('Failed to resolve address for selected location.');
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.map_rounded,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Set on Map',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      searchQuery.trim().isEmpty ? 'Popular Cities' : 'Suggestions',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (searchQuery.trim().isEmpty) ...[
                              ...filteredCities.map((city) {
                                final isSelected = city == _selectedCity;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  title: Text(
                                    city,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? theme.colorScheme.primary : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    cityCoordinates[city] ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20)
                                      : null,
                                  onTap: () {
                                    _selectCityAndResolveCoordinates(city);
                                    Navigator.pop(context);
                                  },
                                );
                              })
                            ] else ...[
                              if (_suggestionsLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20.0),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                )
                              else if (_suggestions.isEmpty)
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  leading: Icon(Icons.location_on, color: theme.colorScheme.primary, size: 20),
                                  title: Text(
                                    'Select "${searchQuery.trim()}"',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  onTap: () {
                                    _selectCityAndResolveCoordinates(searchQuery.trim());
                                    Navigator.pop(context);
                                  },
                                )
                              else
                                ..._suggestions.map((suggestion) {
                                  final name = suggestion['name'] as String;
                                  final city = suggestion['city'] as String;
                                  final lat = suggestion['lat'] as double;
                                  final lng = suggestion['lng'] as double;
                                  
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                    leading: Icon(Icons.location_on, color: theme.colorScheme.primary, size: 20),
                                    title: Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      '${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                    ),
                                    onTap: () {
                                      if (mounted) {
                                        setState(() {
                                          _selectedCity = _capitalizeCity(city);
                                          _selectedLatitude = lat;
                                          _selectedLongitude = lng;
                                        });
                                      }
                                      Navigator.pop(context);
                                    },
                                  );
                                }),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
    );
  }

  // --- API OPERATIONS ---

  Future<void> _handleUpdateProfile(String name, String email, String mobile) async {
    setState(() => _profileLoading = true);

    try {
      final response = await ApiClient.put(
        Uri.parse('${ApiClient.baseUrl}/user/profile'),
        headers: ApiClient.authHeaders(widget.token),
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim(),
          'mobile': mobile.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        widget.onProfileUpdated(name, email, mobile);
        _showSuccess('Profile details updated successfully.');
      } else {
        _showError(data['message'] ?? 'Failed to update profile.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _profileLoading = false);
    }
  }

  Future<void> _handleChangePassword(String currentPassword, String newPassword, String confirmPassword) async {
    setState(() => _profileLoading = true);

    try {
      final response = await ApiClient.put(
        Uri.parse('${ApiClient.baseUrl}/user/password'),
        headers: ApiClient.authHeaders(widget.token),
        body: jsonEncode({
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': confirmPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSuccess('Password updated successfully.');
      } else {
        _showError(data['message'] ?? 'Failed to change password.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _profileLoading = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    setState(() => _profileLoading = true);

    try {
      final response = await ApiClient.delete(
        Uri.parse('${ApiClient.baseUrl}/user'),
        headers: ApiClient.authHeaders(widget.token),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        widget.onLogout();
        _showSuccess('Your account has been deleted successfully.');
      } else {
        _showError(data['message'] ?? 'Failed to delete account.');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      setState(() => _profileLoading = false);
    }
  }

  // --- ACTIONS SHEETS / DIALOGS ---

  void _showEditProfileBottomSheet() {
    final nameController = TextEditingController(text: widget.userName);
    final emailController = TextEditingController(text: widget.userEmail);
    final mobileController = TextEditingController(text: widget.userMobile);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Personal Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter mobile number' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context);
                        _handleUpdateProfile(
                          nameController.text,
                          emailController.text,
                          mobileController.text,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordBottomSheet() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter current password' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) => value == null || value.isEmpty || value.length < 6 ? 'Password must be at least 6 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Confirm your new password';
                      if (value != newPasswordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context);
                        _handleChangePassword(
                          currentPasswordController.text,
                          newPasswordController.text,
                          confirmPasswordController.text,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text(
            'WARNING: Deleting your account will permanently remove all bookings, offers, and details from our system. This action cannot be undone.\n\nAre you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleDeleteAccount();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout of Turf Booking?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _supportTimer?.cancel();
    _supportMessageController.dispose();
    _supportScrollController.dispose();
    _supportFocusNode.dispose();
    _sliderTimer?.cancel();
    _sliderPageController?.dispose();
    _bookingsScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_supportScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _supportScrollController.animateTo(
          _supportScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _fetchSupportMessages({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _supportLoading = true);
    }
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/support/messages'),
        headers: ApiClient.authHeaders(widget.token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _supportMessages = data;
          _supportLoading = false;
        });
        _scrollToBottom();
      } else {
        if (showLoading) setState(() => _supportLoading = false);
      }
    } catch (e) {
      if (showLoading) setState(() => _supportLoading = false);
    }
  }

  Future<void> _sendSupportMessage() async {
    final text = _supportMessageController.text.trim();
    if (text.isEmpty) return;

    _supportMessageController.clear();
    _supportFocusNode.requestFocus();
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiClient.baseUrl}/support/messages'),
        headers: ApiClient.authHeaders(widget.token),
        body: jsonEncode({'message': text}),
      );

      if (response.statusCode == 201) {
        final newMsg = jsonDecode(response.body);
        setState(() {
          _supportMessages.add(newMsg);
        });
        _scrollToBottom();
      } else {
        _showError('Failed to send message.');
      }
    } catch (e) {
      _showError('Network error. Failed to send message.');
    }
  }

  void _ensureChatPolling() {
    if (_supportTimer == null && !_supportLoading) {
      _fetchSupportMessages();
      _supportTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _fetchSupportMessages(showLoading: false);
      });
    }
  }

  Future<void> _openTurfDetail(Turf turf) async {
    final navigator = Navigator.of(context);
    final result = await navigator.push(
      MaterialPageRoute(
        builder: (context) => TurfDetailScreen(turf: turf, token: widget.token),
      ),
    );
    if (result == 'show_client_bookings' && mounted) {
      setState(() {
        _currentIndex = 4;
      });
      _fetchClientBookings();
    } else if (result == 'show_bookings' && mounted) {
      setState(() {
        _currentIndex = 1;
      });
      _fetchBookings();
    }
  }

  Widget _buildHomeTab() {
    return HomeTab(
      userName: widget.userName,
      sliderLoading: _sliderLoading,
      sliderImages: _sliderImages,
      sliderPageController: _sliderPageController,
      sliderCurrentPage: _sliderCurrentPage,
      isLocating: _isLocating,
      selectedCity: _selectedCity,
      turfsLoading: _turfsLoading,
      filteredTurfs: _filteredTurfs,
      selectedLatitude: _selectedLatitude,
      selectedLongitude: _selectedLongitude,
      calculateDistance: _calculateDistance,
      onSliderPageChanged: (index) => setState(() => _sliderCurrentPage = index),
      onOpenCityPicker: _showCityPickerDialog,
      onRefreshTurfs: _fetchTurfs,
      onOpenTurfDetail: _openTurfDetail,
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return BookingsTab(
          bookingsFilter: _bookingsFilter,
          bookingsLoading: _bookingsLoading,
          bookings: _bookings,
          hasMoreBookings: _hasMoreBookings,
          bookingsScrollController: _bookingsScrollController,
          onFilterChanged: (filter) {
            setState(() {
              _bookingsFilter = filter;
              _bookings = [];
              _bookingsPage = 1;
              _hasMoreBookings = true;
            });
            _fetchBookings(refresh: true);
          },
          onRefresh: () => _fetchBookings(refresh: true),
          onShowBookingDetails: _showBookingDetailsBottomSheet,
        );
      case 2:
        return SupportTab(
          showChatWindow: _showChatWindow,
          supportLoading: _supportLoading,
          isChatPollingActive: _supportTimer != null,
          supportMessages: _supportMessages,
          supportMessageController: _supportMessageController,
          supportScrollController: _supportScrollController,
          supportFocusNode: _supportFocusNode,
          onOpenChat: () => setState(() => _showChatWindow = true),
          onCloseChat: () {
            setState(() => _showChatWindow = false);
            _supportTimer?.cancel();
            _supportTimer = null;
          },
          onEnsureChatPolling: _ensureChatPolling,
          onSendMessage: _sendSupportMessage,
        );
      case 3:
        return ProfileTab(
          userName: widget.userName,
          userEmail: widget.userEmail,
          userMobile: widget.userMobile,
          onEditProfile: _showEditProfileBottomSheet,
          onChangePassword: _showChangePasswordBottomSheet,
          onDeleteAccount: _showDeleteAccountDialog,
        );
      case 4:
        return ClientBookingsTab(
          manageableTurfs: _manageableTurfs,
          clientBookingSelectedTurfId: _clientBookingSelectedTurfId,
          clientBookingFilter: _clientBookingFilter,
          clientBookingSelectedDate: _clientBookingSelectedDate,
          clientBookingsLoading: _clientBookingsLoading,
          clientBookings: _clientBookings,
          onTurfFilterChanged: (newValue) {
            setState(() {
              _clientBookingSelectedTurfId = newValue;
            });
            _fetchClientBookings();
          },
          onStatusFilterChanged: (filter) {
            setState(() {
              _clientBookingFilter = filter;
            });
            _fetchClientBookings();
          },
          onDateChanged: (date) {
            setState(() {
              _clientBookingSelectedDate = date;
            });
            _fetchClientBookings();
          },
          onRefresh: _fetchClientBookings,
          onShowBookingDetails: _showBookingDetailsBottomSheet,
        );
      case 5:
        return DashboardTab(
          dashboardStatsLoading: _dashboardStatsLoading,
          dashboardStats: _dashboardStats,
          dashboardSelectedTurfId: _dashboardSelectedTurfId,
          onRetry: _fetchDashboardStats,
          onRefresh: _fetchDashboardStats,
          onTurfFilterChanged: (newValue) {
            setState(() {
              _dashboardSelectedTurfId = newValue;
            });
            _fetchDashboardStats();
          },
          onViewBookingsForDate: (date) {
            setState(() {
              _currentIndex = 4;
              _clientBookingSelectedDate = date;
            });
            _fetchClientBookings();
          },
        );
      default:
        return _buildHomeTab();
    }
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Turf Booking';
      case 1:
        return 'My Bookings';
      case 2:
        return 'Customer Support';
      case 3:
        return 'My Profile';
      case 4:
        return 'Client Bookings';
      case 5:
        return 'Turf Admin Dashboard';
      default:
        return 'Turf Booking';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not on support tab or chat window closed, cancel support timer
    if ((_currentIndex != 2 || !_showChatWindow) && _supportTimer != null) {
      _supportTimer?.cancel();
      _supportTimer = null;
    }

    final theme = Theme.of(context);


    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                widget.userName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text(widget.userEmail),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.brightness == Brightness.dark
                    ? const Color(0xFF1E2022)
                    : Colors.white,
                child: Text(
                  widget.userName.substring(0, widget.userName.length > 1 ? 2 : 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('Home'),
                    selected: _currentIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('My Bookings'),
                    selected: _currentIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Support'),
                    selected: _currentIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Profile'),
                    selected: _currentIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 3);
                    },
                  ),
                  if (_userRoles.any((r) => r == 'turf-admin' || r == 'manager')) ...[
                    const Divider(height: 1),
                    if (_userRoles.any((r) => r == 'turf-admin'))
                      ListTile(
                        leading: const Icon(Icons.dashboard_outlined),
                        title: const Text('Dashboard'),
                        selected: _currentIndex == 5,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentIndex = 5);
                        },
                      ),
                    if (_userRoles.any((r) => r == 'turf-admin' || r == 'manager'))
                      ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Client Booking'),
                        selected: _currentIndex == 4,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentIndex = 4);
                        },
                      ),
                  ],
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_profileLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex > 1 ? 0 : _currentIndex,
        selectedItemColor: _currentIndex <= 1 ? theme.colorScheme.primary : Colors.grey,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            _fetchBookings();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Bookings',
          ),
        ],
      ),
    );
  }

  void _showBookingDetailsBottomSheet(BuildContext context, Booking bookingDate) {
    final theme = Theme.of(context);
    final slots = bookingDate.slots;
    final isConfirmed = bookingDate.isConfirmed;
    final isCancelled = bookingDate.isCancelled;
    final isPaid = bookingDate.isPaid;
    final bookingType = bookingDate.bookingType;
    final String bookingTurfId = bookingDate.turfId ?? '';
    final bool isManagerOrAdmin = _userRoles.any((r) => ['turf-admin', 'manager'].contains(r)) &&
        _manageableTurfIds.contains(bookingTurfId);

    final bool isCancellationActive = bookingDate.isCancellationActive;
    final int cancellationHours = bookingDate.cancellationHours;
    final double cancellationFee = bookingDate.cancellationFee;

    bool canCancel = true;
    String? cancellationReason;
    if (!isManagerOrAdmin) {
      if (!isCancellationActive) {
        canCancel = false;
        cancellationReason = 'Cancellation Disabled';
      } else {
        try {
          final dateRawStr = bookingDate.dateRaw ?? '';
          if (dateRawStr.isNotEmpty) {
            String earliestTimeStr = '00:00';
            if (slots.isNotEmpty) {
              final firstSlot = slots.first.timeRange ?? '';
              if (firstSlot.contains(' - ')) {
                final timePart = firstSlot.split(' - ').first;
                final parts = timePart.split(' ');
                if (parts.length == 2) {
                  final timeDigits = parts[0].split(':');
                  int hour = int.parse(timeDigits[0]);
                  final min = int.parse(timeDigits[1]);
                  final amPm = parts[1].toUpperCase();
                  if (amPm == 'PM' && hour != 12) hour += 12;
                  if (amPm == 'AM' && hour == 12) hour = 0;
                  earliestTimeStr = "${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}";
                }
              }
            }
            final DateTime startDateTime = DateTime.parse("$dateRawStr $earliestTimeStr");
            final diff = startDateTime.difference(DateTime.now());
            if (diff.inHours < cancellationHours) {
              canCancel = false;
              cancellationReason = 'Too Close to Session';
            }
          }
        } catch (_) {}
      }
    } else {
      if (!isCancellationActive) {
        canCancel = false;
        cancellationReason = 'Cancellation Disabled';
      }
    }

    String formattedBookingType = 'Day Session';
    if (bookingType == 'long') {
      formattedBookingType = 'Long Session';
    } else if (bookingType == 'scattered') {
      formattedBookingType = 'Scattered Slots';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          bookingDate.turfName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isConfirmed
                              ? Colors.green.withValues(alpha: 0.1)
                              : (isCancelled
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          bookingDate.status,
                          style: TextStyle(
                            color: isConfirmed
                                ? Colors.green
                                : (isCancelled ? Colors.red : Colors.orange),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        bookingDate.bookingNumber != null && bookingDate.bookingNumber!.isNotEmpty
                            ? bookingDate.bookingNumber!
                            : 'Booking Reference #${bookingDate.bookingId}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          final bNum = bookingDate.bookingNumber ?? '#${bookingDate.bookingId}';
                          Clipboard.setData(ClipboardData(text: bNum));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied $bNum to clipboard'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.copy, size: 14, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Booking Details',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.event, 'Booking Date', bookingDate.bookingDate),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.schedule, 'Session Type', formattedBookingType),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.calendar_today, 'Booked On', bookingDate.dateOfBooking ?? ''),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.payment,
                    'Payment Status',
                    bookingDate.datePaymentStatus,
                    valueColor: isPaid ? Colors.blue : Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.cancel_outlined,
                    'Cancellation Policy',
                    isCancellationActive
                        ? 'Cancel up to $cancellationHours hrs prior (Fee: ₹${cancellationFee.toStringAsFixed(2)})'
                        : 'No cancellation allowed',
                    valueColor: isCancellationActive ? Colors.green : Colors.red,
                  ),
                  if (isCancelled) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.event_busy,
                      'Cancelled At',
                      bookingDate.cancelledAt ?? 'N/A',
                      valueColor: Colors.red,
                    ),
                    if (bookingDate.cancellationFeeApplied > 0) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.money_off,
                        'Fee Applied',
                        '₹${bookingDate.cancellationFeeApplied.toStringAsFixed(2)}',
                        valueColor: Colors.orange,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.currency_rupee,
                      'Refund Amount',
                      '₹${bookingDate.refundAmount.toStringAsFixed(2)}',
                      valueColor: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.info_outline,
                      'Refund Status',
                      bookingDate.refundStatus ?? 'None',
                      valueColor: (bookingDate.refundStatus == 'Refunded') ? Colors.green : Colors.grey,
                    ),
                    if (bookingDate.refundMethod != null && bookingDate.refundMethod != 'None') ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.account_balance_wallet_outlined,
                        'Refund Method',
                        bookingDate.refundMethod == 'razorpay' ? 'Razorpay Online' : 'Cash / Offline Refund',
                        valueColor: bookingDate.refundMethod == 'razorpay' ? Colors.blue : Colors.orange,
                      ),
                    ],
                    if (bookingDate.refundedAt != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.history,
                        'Refunded At',
                        bookingDate.refundedAt ?? 'N/A',
                        valueColor: Colors.green,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _buildRefundBreakupCard(
                      bookingDate.safeCancellationBreakup,
                      title: 'Refund & Deductions Summary',
                      isSettled: true,
                      refundStatus: bookingDate.refundStatus,
                      refundMode: bookingDate.refundMethod,
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Customer Details',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (bookingDate.customerMobile != null && bookingDate.customerMobile != 'N/A')
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone, color: Color(0xFF10B981)),
                              tooltip: 'Call Client',
                              onPressed: () async {
                                final phone = bookingDate.customerMobile!;
                                final Uri callUri = Uri(scheme: 'tel', path: phone);
                                if (await canLaunchUrl(callUri)) {
                                  await launchUrl(callUri);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                              tooltip: 'Share via WhatsApp',
                              onPressed: () async {
                                final phone = bookingDate.customerMobile!;
                                final turfName = bookingDate.turfName;
                                final date = bookingDate.bookingDate;
                                final slotsText = slots.map((s) => s.timeRange).join(', ');
                                final total = bookingDate.amount.toStringAsFixed(2);
                                final paid = bookingDate.datePaidAmount.toStringAsFixed(2);
                                final balance = bookingDate.dateBalanceAmount.toStringAsFixed(2);

                                String message = bookingDate.shareMessageTemplate ??
                                    "*Booking Confirmed!*\n\n⚽ *Turf:* {turf_name}\n📅 *Date:* {booking_date}\n⏰ *Slots:* {slots}\n\n💳 *Payment Details:*\n• Total Amount: ₹{total_amount}\n• Paid Amount: ₹{paid_amount}\n• Balance Due: ₹{balance_amount}\n\nThank you for booking with us!";

                                message = message
                                    .replaceAll('{customer_name}', bookingDate.customerName ?? 'N/A')
                                    .replaceAll('{turf_name}', turfName)
                                    .replaceAll('{booking_date}', date)
                                    .replaceAll('{slots}', slotsText)
                                    .replaceAll('{total_amount}', total)
                                    .replaceAll('{paid_amount}', paid)
                                    .replaceAll('{balance_amount}', balance);

                                String formattedPhone = phone.trim();
                                if (formattedPhone.length == 10) {
                                  formattedPhone = "91$formattedPhone";
                                } else {
                                  formattedPhone = formattedPhone.replaceAll(RegExp(r'\D'), '');
                                }

                                final whatsappUri = Uri.parse("https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}");
                                if (await canLaunchUrl(whatsappUri)) {
                                  await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.person_outline, 'Name', bookingDate.customerName ?? 'N/A'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.phone_android, 'Mobile', bookingDate.customerMobile ?? 'N/A'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.mail_outline, 'Email', bookingDate.customerEmail ?? 'N/A'),
                  if (bookingDate.customerGstin != null && bookingDate.customerGstin!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.receipt_long, 'B2B GSTIN', bookingDate.customerGstin!),
                    if (bookingDate.customerCompanyName != null && bookingDate.customerCompanyName!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.business, 'Company Name', bookingDate.customerCompanyName!),
                    ],
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Booked Slots (${slots.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: slots.map<Widget>((slot) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              slot.timeRange ?? '',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (bookingDate.payments.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Payment History',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: bookingDate.payments.map<Widget>((payment) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    payment.paymentMethod,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${payment.paidAt}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "₹${payment.amount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const Divider(),
                  const SizedBox(height: 16),
                  if (bookingDate.turfGstAmount > 0 || bookingDate.platformFee > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Base Slot Price',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Text(
                          '₹${(bookingDate.taxableAmount > 0 ? bookingDate.taxableAmount : (bookingDate.amount - bookingDate.turfGstAmount - bookingDate.platformFee - bookingDate.platformFeeGst)).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (bookingDate.turfGstAmount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            bookingDate.turfGstType == 'included'
                                ? 'Turf GST (${bookingDate.turfGstRate.toStringAsFixed(0)}% incl.)'
                                : 'Turf GST (${bookingDate.turfGstRate.toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          Text(
                            bookingDate.turfGstType == 'included'
                                ? '₹${bookingDate.turfGstAmount.toStringAsFixed(2)}'
                                : '+₹${bookingDate.turfGstAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                    if (bookingDate.platformFee > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Platform Fee (incl. GST)',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          Text(
                            '+₹${(bookingDate.platformFee + bookingDate.platformFeeGst).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '₹${bookingDate.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Price Paid',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '₹${bookingDate.datePaidAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Balance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${bookingDate.dateBalanceAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: bookingDate.dateBalanceAmount > 0
                              ? Colors.orange
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (isManagerOrAdmin && !isPaid) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showRecordPaymentDialog(context, bookingDate),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Record Payment'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (bookingDate.status != 'Cancelled') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canCancel ? () {
                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              final String dateName = bookingDate.bookingDate;
                              final bool hasMultipleDates = bookingDate.activeDatesCount > 1;
                              final CancellationBreakup singleBreakup = bookingDate.safeCancellationBreakup;
                              final CancellationBreakup allBreakup = bookingDate.allDatesCancellationBreakup ?? singleBreakup;

                              int selectedScope = 0; // 0 for dateName, 1 for all dates

                              return StatefulBuilder(
                                builder: (context, setDialogState) {
                                  final currentBreakup = selectedScope == 0 ? singleBreakup : allBreakup;

                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    title: Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 22),
                                        const SizedBox(width: 8),
                                        const Text('Cancel Booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hasMultipleDates
                                                ? 'Do you want to cancel only $dateName or all dates of this booking?'
                                                : 'Are you sure you want to cancel your booking for $dateName?',
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                          ),
                                          if (hasMultipleDates) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: GestureDetector(
                                                      onTap: () => setDialogState(() => selectedScope = 0),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                                        decoration: BoxDecoration(
                                                          color: selectedScope == 0 ? Colors.white : Colors.transparent,
                                                          borderRadius: BorderRadius.circular(10),
                                                          boxShadow: selectedScope == 0
                                                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                                                              : null,
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          'Only $dateName',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: selectedScope == 0 ? FontWeight.bold : FontWeight.w500,
                                                            color: selectedScope == 0 ? Colors.red.shade800 : Colors.grey.shade700,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: GestureDetector(
                                                      onTap: () => setDialogState(() => selectedScope = 1),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                                        decoration: BoxDecoration(
                                                          color: selectedScope == 1 ? Colors.white : Colors.transparent,
                                                          borderRadius: BorderRadius.circular(10),
                                                          boxShadow: selectedScope == 1
                                                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                                                              : null,
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          'All Dates (${bookingDate.activeDatesCount})',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: selectedScope == 1 ? FontWeight.bold : FontWeight.w500,
                                                            color: selectedScope == 1 ? Colors.red.shade800 : Colors.grey.shade700,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          _buildRefundBreakupCard(
                                            currentBreakup,
                                            title: 'Refund & Deductions Summary',
                                            isSettled: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: const Text('Keep Booking'),
                                      ),
                                      if (!hasMultipleDates)
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(dialogContext);
                                            Navigator.pop(context);
                                            _cancelBooking(bookingDate.bookingId, bookingDateIds: [bookingDate.id]);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Cancel Booking'),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(dialogContext);
                                            Navigator.pop(context);
                                            if (selectedScope == 0) {
                                              _cancelBooking(bookingDate.bookingId, bookingDateIds: [bookingDate.id]);
                                            } else {
                                              _cancelBooking(bookingDate.bookingId);
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: Text(selectedScope == 0 ? 'Cancel $dateName' : 'Cancel All Dates'),
                                        ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canCancel ? Colors.red.shade50 : Colors.grey.shade100,
                          foregroundColor: canCancel ? Colors.red : Colors.grey,
                          disabledBackgroundColor: Colors.grey.shade100,
                          disabledForegroundColor: Colors.grey,
                          elevation: 0,
                          side: BorderSide(
                            color: canCancel ? Colors.red.shade200 : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              canCancel ? Icons.cancel_outlined : Icons.lock_outline,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              canCancel ? 'Cancel Booking' : (cancellationReason ?? 'Cannot Cancel'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close Details'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        );
      },
    );
  }

  void _showRecordPaymentDialog(BuildContext context, Booking bookingDate) {
    final id = bookingDate.id;
    String method = 'Cash';
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Record Offline Payment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Payment Method:'),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: method,
                      isExpanded: true,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            method = val;
                          });
                        }
                      },
                      items: ['Cash', 'UPI', 'Other'].map((m) {
                        return DropdownMenuItem<String>(
                          value: m,
                          child: Text(m),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (₹)',
                        hintText: 'Enter amount collected',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    try {
                      final response = await ApiClient.post(
                        Uri.parse('${ApiClient.baseUrl}/booking-dates/$id/payments'),
                        headers: ApiClient.authHeaders(widget.token),
                        body: jsonEncode({
                          'payment_method': method,
                          'amount': amt,
                        }),
                      );

                      if (response.statusCode == 200) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        Navigator.pop(context);
                        _showSuccess('Payment recorded successfully.');
                        _fetchBookings(refresh: true);
                        _fetchClientBookings();
                        _fetchDashboardStats();
                      } else {
                        if (!context.mounted) return;
                        final msg = jsonDecode(response.body)['message'] ?? 'Failed to record payment.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: Colors.red),
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildRefundBreakupCard(
    CancellationBreakup breakup, {
    String? title,
    bool isSettled = false,
    String? refundStatus,
    String? refundMode,
  }) {
    final bool hasDeductions = breakup.totalDeductions > 0;
    final bool hasRefund = breakup.refundAmount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Icon(
                  isSettled ? Icons.receipt_long : Icons.calculate_outlined,
                  size: 16,
                  color: Colors.grey.shade800,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          _buildBreakupRow('Gross Amount Paid', '₹${breakup.grossPaid.toStringAsFixed(2)}', isBold: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, color: Colors.black12),
          ),
          const Text(
            'Deductions Applied:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
          ),
          const SizedBox(height: 3),
          if (breakup.turfCancellationFee > 0)
            _buildBreakupSubRow('Turf Cancellation Fee', '-₹${breakup.turfCancellationFee.toStringAsFixed(2)}', color: Colors.red.shade700),
          if (breakup.platformFeeRetained > 0)
            _buildBreakupSubRow('Platform Fee (Non-refundable)', '-₹${breakup.platformFeeRetained.toStringAsFixed(2)}', color: Colors.red.shade700),
          if (breakup.saasCancellationFee > 0)
            _buildBreakupSubRow('SaaS Processing Fee', '-₹${breakup.saasCancellationFee.toStringAsFixed(2)}', color: Colors.red.shade700),
          if (!hasDeductions)
            _buildBreakupSubRow('No deductions applied', '₹0.00', color: Colors.green.shade700),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, color: Colors.black12),
          ),
          _buildBreakupRow(
            'Total Deductions',
            hasDeductions ? '-₹${breakup.totalDeductions.toStringAsFixed(2)}' : '₹0.00',
            color: hasDeductions ? Colors.red.shade800 : Colors.black87,
            isBold: true,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: hasRefund ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasRefund ? Colors.green.shade200 : Colors.orange.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSettled ? 'Refund Amount' : 'Estimated Refund',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: hasRefund ? Colors.green.shade900 : Colors.orange.shade900,
                      ),
                    ),
                    if (isSettled && refundStatus != null)
                      Text(
                        'Status: $refundStatus',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: (refundStatus == 'Refunded') ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                  ],
                ),
                Text(
                  '₹${breakup.refundAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: hasRefund ? Colors.green.shade900 : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ),
          if (refundMode != null && refundMode != 'None') ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Mode: ${refundMode == 'razorpay' ? 'Razorpay (Online Gateway)' : (refundMode == 'offline' ? 'Cash / Offline Refund' : refundMode)}',
                style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakupRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakupSubRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '• $label',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}


