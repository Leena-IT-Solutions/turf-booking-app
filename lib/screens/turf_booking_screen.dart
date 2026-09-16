import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/booking_type.dart';
import '../models/turf.dart';
import '../widgets/multi_date_picker_dialog.dart';
import 'order_preview_screen.dart';

class TurfBookingScreen extends StatefulWidget {
  final Turf turf;
  final String? token;

  const TurfBookingScreen({super.key, required this.turf, this.token});

  @override
  State<TurfBookingScreen> createState() => _TurfBookingScreenState();
}

class _TurfBookingScreenState extends State<TurfBookingScreen> {
  BookingType _selectedType = BookingType.day;

  // Day Booking State
  DateTime _singleDate = DateTime.now();

  // Long Booking State (Date Range)
  DateTimeRange? _dateRange;

  // Scattered Booking State (List of dates)
  final List<DateTime> _scatteredDates = [];

  // Slots State
  List<dynamic> _slots = [];
  bool _slotsLoading = false;
  final List<int> _selectedSlotIds = [];
  final bool _submittingBooking = false;
  int _minSlotsBooking = 2;

  @override
  void initState() {
    super.initState();
    _fetchConfig();
    _fetchSlots();
  }

  Future<void> _fetchConfig() async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiClient.baseUrl}/config'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _minSlotsBooking = data['min_slots_booking'] ?? 2;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching config: $e');
    }
  }

  Future<void> _fetchSlots() async {
    final turfId = widget.turf.id;
    final List<String> dates = [];
    
    if (_selectedType == BookingType.day) {
      dates.add("${_singleDate.year}-${_singleDate.month.toString().padLeft(2, '0')}-${_singleDate.day.toString().padLeft(2, '0')}");
    } else if (_selectedType == BookingType.long && _dateRange != null) {
      var current = _dateRange!.start;
      final end = _dateRange!.end;
      while (!current.isAfter(end)) {
        dates.add("${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}");
        current = current.add(const Duration(days: 1));
      }
    } else if (_selectedType == BookingType.scattered && _scatteredDates.isNotEmpty) {
      for (final date in _scatteredDates) {
        dates.add("${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}");
      }
    }

    if (dates.isEmpty) {
      setState(() {
        _slots = [];
      });
      return;
    }

    setState(() {
      _slotsLoading = true;
    });

    try {
      String url;
      if (_selectedType == BookingType.day) {
        url = '${ApiClient.baseUrl}/turfs/$turfId/slots?date=${dates[0]}';
      } else {
        final queryParams = dates.map((d) => 'dates[]=$d').join('&');
        url = '${ApiClient.baseUrl}/turfs/$turfId/slots?$queryParams';
      }
      final response = await ApiClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Dont show booked slots and slot locks for long and scattered booking
        if (_selectedType == BookingType.long || _selectedType == BookingType.scattered) {
          for (var s in data) {
            s['is_booked'] = false;
            s['is_locked'] = false;
          }
        }

        if (mounted) {
          setState(() {
            _slots = data;
            _slotsLoading = false;
            _selectedSlotIds.clear();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _slotsLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching slots: $e');
      if (mounted) {
        setState(() {
          _slotsLoading = false;
        });
      }
    }
  }

  Widget _buildBookingTypeSelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking Option',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTypeChip(BookingType.day, 'Day Booking', Icons.today)),
            const SizedBox(width: 8),
            Expanded(child: _buildTypeChip(BookingType.long, 'Long Booking', Icons.date_range)),
            const SizedBox(width: 8),
            Expanded(child: _buildTypeChip(BookingType.scattered, 'Scattered Booking', Icons.calendar_month)),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(BookingType type, String label, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _selectedType == type;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedSlotIds.clear();
        });
        _fetchSlots();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? const Color(0xFF1E2022) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.black87),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerArea() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (_selectedType) {
      case BookingType.day:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Date',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: _isPrevDateDisabled()
                          ? Colors.grey.withValues(alpha: 0.4)
                          : theme.colorScheme.primary,
                      size: 20,
                    ),
                    onPressed: _isPrevDateDisabled()
                        ? null
                        : () {
                            setState(() {
                              _singleDate = _singleDate.subtract(const Duration(days: 1));
                            });
                            _fetchSlots();
                          },
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _singleDate,
                          firstDate: DateTime.now().subtract(const Duration(hours: 12)),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setState(() {
                            _singleDate = picked;
                          });
                          _fetchSlots();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getDayOfWeekName(_singleDate),
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_singleDate.day} ${_getMonthName(_singleDate.month)} ${_singleDate.year}',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      color: _isNextDateDisabled()
                          ? Colors.grey.withValues(alpha: 0.4)
                          : theme.colorScheme.primary,
                      size: 20,
                    ),
                    onPressed: _isNextDateDisabled()
                        ? null
                        : () {
                            setState(() {
                              _singleDate = _singleDate.add(const Duration(days: 1));
                            });
                            _fetchSlots();
                          },
                  ),
                ],
              ),
            ),
          ],
        );

      case BookingType.long:
        final rangeText = _dateRange == null
            ? 'Select start & end date'
            : '${_dateRange!.start.day} ${_getMonthName(_dateRange!.start.month)} - ${_dateRange!.end.day} ${_getMonthName(_dateRange!.end.month)} (${_dateRange!.duration.inDays + 1} Days)';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Date Range',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E2022) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!, width: 1.2),
              ),
              child: ListTile(
                leading: Icon(Icons.date_range, color: theme.colorScheme.primary),
                title: Text(rangeText),
                subtitle: Text(_dateRange == null ? 'Tap to choose range' : 'Tap to change range'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    initialDateRange: _dateRange,
                  );
                  if (picked != null) {
                    setState(() {
                      _dateRange = picked;
                    });
                    _fetchSlots();
                  }
                },
              ),
            ),
          ],
        );

      case BookingType.scattered:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Dates (${_scatteredDates.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final pickedDates = await showDialog<List<DateTime>>(
                      context: context,
                      builder: (context) => MultiDatePickerDialog(initialDates: _scatteredDates),
                    );
                    if (pickedDates != null) {
                      setState(() {
                        _scatteredDates.clear();
                        _scatteredDates.addAll(pickedDates);
                        _scatteredDates.sort((a, b) => a.compareTo(b));
                      });
                      _fetchSlots();
                    }
                  },
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text('Select Dates', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_scatteredDates.isEmpty)
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
                        Icon(Icons.calendar_month, color: Colors.grey, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'No dates selected yet',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _scatteredDates.map((date) {
                  return Chip(
                    label: Text(
                      '${date.day} ${_getMonthName(date.month)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() {
                        _scatteredDates.remove(date);
                      });
                      _fetchSlots();
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: isDark ? const Color(0xFF1E2022) : Colors.grey[200],
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
          ],
        );
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getDayOfWeekName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  bool _isPrevDateDisabled() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !_singleDate.isAfter(today);
  }

  bool _isNextDateDisabled() {
    final limit = DateTime.now().add(const Duration(days: 90));
    final nextDay = DateTime(_singleDate.year, _singleDate.month, _singleDate.day).add(const Duration(days: 1));
    return nextDay.isAfter(limit);
  }

  Map<String, List<dynamic>> _getGroupedSlots() {
    final Map<String, List<dynamic>> grouped = {};
    for (final slot in _slots) {
      final category = slot['category'] ?? 'Other';
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(slot);
    }
    return grouped;
  }

  Widget _buildSlotsSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_slotsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_selectedType == BookingType.long && _dateRange == null) {
      return _buildEmptySlotsPrompt('Select a date range to view slots');
    }
    if (_selectedType == BookingType.scattered && _scatteredDates.isEmpty) {
      return _buildEmptySlotsPrompt('Select dates to view slots');
    }

    if (_slots.isEmpty) {
      return _buildEmptySlotsPrompt('No slots available for the selected date.');
    }

    final grouped = _getGroupedSlots();
    final orderedCategories = ['Midnight', 'Morning', 'Afternoon', 'Evening', 'Night'];
    final sortedCategories = grouped.keys.toList()
      ..sort((a, b) {
        final idxA = orderedCategories.indexOf(a);
        final idxB = orderedCategories.indexOf(b);
        if (idxA == -1 && idxB == -1) return a.compareTo(b);
        if (idxA == -1) return 1;
        if (idxB == -1) return -1;
        return idxA.compareTo(idxB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedCategories.map((category) {
        final categorySlots = grouped[category]!;
        final icon = _getCategoryIcon(category);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 20, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '$category Slots',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categorySlots.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.3,
              ),
              itemBuilder: (context, index) {
                final slot = categorySlots[index];
                final int id = slot['id'];
                final String label = slot['time_label'] ?? '';
                final double price = (slot['price'] as num).toDouble();
                final bool isLocked = (_selectedType == BookingType.day) && (slot['is_locked'] == true);
                final String lockReason = slot['lock_reason'] ?? 'Maintenance';
                final bool isBooked = (_selectedType == BookingType.day) && (slot['is_booked'] == true || slot['is_locked'] == true);
                final bool isSelected = _selectedSlotIds.contains(id);

                if (isBooked) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isLocked
                          ? (isDark ? Colors.amber[900]?.withValues(alpha: 0.2) : Colors.amber[50])
                          : (isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey[100]?.withValues(alpha: 0.8)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLocked
                            ? (isDark ? Colors.amber[800]! : Colors.amber[300]!)
                            : (isDark ? Colors.grey[900]! : Colors.grey[200]!),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            isLocked ? Icons.lock : Icons.lock_outline, 
                            size: 14, 
                            color: isLocked ? Colors.amber[600] : Colors.grey.withValues(alpha: 0.5),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: isLocked ? Colors.amber.withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isLocked ? 'Locked ($lockReason)' : 'Booked',
                                style: TextStyle(
                                  color: isLocked ? Colors.amber[700] : Colors.red[400],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return InkWell(
                  onTap: () => _onSlotTapped(id),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withValues(alpha: 0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected
                          ? null
                          : (isDark ? const Color(0xFF1E2022) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? theme.colorScheme.primary.withValues(alpha: 0.5)
                            : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                        width: 1.5,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          right: 0,
                          child: isSelected
                              ? const Icon(
                                  Icons.check_circle, 
                                  size: 16, 
                                  color: Colors.white,
                                )
                              : Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected 
                                      ? Colors.white.withValues(alpha: 0.9) 
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'morning':
        return Icons.wb_sunny_outlined;
      case 'afternoon':
        return Icons.wb_sunny;
      case 'evening':
        return Icons.wb_twilight;
      case 'night':
        return Icons.nights_stay;
      default:
        return Icons.nightlight_round;
    }
  }

  void _onSlotTapped(int tappedId) {
    final tappedIndex = _slots.indexWhere((s) => s['id'] == tappedId);
    if (tappedIndex == -1) return;

    final tappedSlot = _slots[tappedIndex];
    final bool isBooked = _selectedType == BookingType.day && (tappedSlot['is_booked'] == true || tappedSlot['is_locked'] == true);
    if (isBooked) return;

    final bool isSelected = _selectedSlotIds.contains(tappedId);

    // Helper: Partition selected slot IDs into list of contiguous index blocks
    List<List<int>> getContiguousBlocks(List<int> ids) {
      if (ids.isEmpty) return [];
      final List<int> indices = ids.map((id) => _slots.indexWhere((s) => s['id'] == id)).toList()..sort();

      final List<List<int>> blocks = [];
      List<int> currentBlock = [indices[0]];

      for (int i = 1; i < indices.length; i++) {
        if (indices[i] == indices[i - 1] + 1) {
          currentBlock.add(indices[i]);
        } else {
          blocks.add(currentBlock);
          currentBlock = [indices[i]];
        }
      }
      blocks.add(currentBlock);

      return blocks.map((block) {
        return block.map((idx) => _slots[idx]['id'] as int).toList();
      }).toList();
    }

    if (_minSlotsBooking <= 1) {
      setState(() {
        if (isSelected) {
          _selectedSlotIds.remove(tappedId);
        } else {
          _selectedSlotIds.add(tappedId);
        }
      });
      return;
    }

    if (isSelected) {
      // User tapped a selected slot. Remove the entire contiguous block it belongs to.
      final blocks = getContiguousBlocks(_selectedSlotIds);
      final targetBlock = blocks.firstWhere(
        (block) => block.contains(tappedId),
        orElse: () => [],
      );

      setState(() {
        for (final id in targetBlock) {
          _selectedSlotIds.remove(id);
        }
      });
      return;
    }

    // Tapped slot is NOT currently selected.
    // Check if it is adjacent to any of the currently selected blocks.
    final blocks = getContiguousBlocks(_selectedSlotIds);
    List<int>? adjacentBlock;

    for (final block in blocks) {
      final List<int> indices = block.map((id) => _slots.indexWhere((s) => s['id'] == id)).toList()..sort();
      final minIdx = indices.first;
      final maxIdx = indices.last;

      if (tappedIndex == minIdx - 1 || tappedIndex == maxIdx + 1) {
        adjacentBlock = block;
        break;
      }
    }

    if (adjacentBlock != null) {
      setState(() {
        _selectedSlotIds.add(tappedId);
      });
      return;
    }

    // Start a new contiguous block
    List<int> candidateIds = [];
    bool forwardValid = true;

    if (tappedIndex + _minSlotsBooking <= _slots.length) {
      for (int i = 0; i < _minSlotsBooking; i++) {
        final slot = _slots[tappedIndex + i];
        if (slot['is_booked'] == true || _selectedSlotIds.contains(slot['id'])) {
          forwardValid = false;
          break;
        }
        candidateIds.add(slot['id']);
      }
    } else {
      forwardValid = false;
    }

    if (forwardValid) {
      setState(() {
        _selectedSlotIds.addAll(candidateIds);
      });
      return;
    }

    candidateIds.clear();
    bool backwardValid = true;

    if (tappedIndex - _minSlotsBooking + 1 >= 0) {
      for (int i = _minSlotsBooking - 1; i >= 0; i--) {
        final slot = _slots[tappedIndex - i];
        if (slot['is_booked'] == true || _selectedSlotIds.contains(slot['id'])) {
          backwardValid = false;
          break;
        }
        candidateIds.add(slot['id']);
      }
    } else {
      backwardValid = false;
    }

    if (backwardValid) {
      setState(() {
        _selectedSlotIds.addAll(candidateIds);
      });
      return;
    }

    for (int startIdx = tappedIndex - _minSlotsBooking + 1; startIdx <= tappedIndex; startIdx++) {
      if (startIdx >= 0 && startIdx + _minSlotsBooking <= _slots.length) {
        candidateIds.clear();
        bool windowValid = true;
        for (int i = 0; i < _minSlotsBooking; i++) {
          final slot = _slots[startIdx + i];
          if (slot['is_booked'] == true || _selectedSlotIds.contains(slot['id'])) {
            windowValid = false;
            break;
          }
          candidateIds.add(slot['id']);
        }
        if (windowValid) {
          setState(() {
            _selectedSlotIds.addAll(candidateIds);
          });
          return;
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cannot book this slot. A minimum of $_minSlotsBooking consecutive slots is required.'),
      ),
    );
  }

  Widget _buildEmptySlotsPrompt(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey.withValues(alpha: 0.5), size: 36),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitBooking() async {
    final List<int> indices = _selectedSlotIds.map((id) => _slots.indexWhere((s) => s['id'] == id)).toList()..sort();
    if (indices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one time slot.')),
      );
      return;
    }

    final List<List<int>> blocks = [];
    List<int> currentBlock = [indices[0]];

    for (int i = 1; i < indices.length; i++) {
      if (indices[i] == indices[i - 1] + 1) {
        currentBlock.add(indices[i]);
      } else {
        blocks.add(currentBlock);
        currentBlock = [indices[i]];
      }
    }
    blocks.add(currentBlock);

    for (final block in blocks) {
      if (block.length < _minSlotsBooking) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Each consecutive block of selected slots must contain at least $_minSlotsBooking slots.')),
        );
        return;
      }
    }

    final List<String> dates = [];
    if (_selectedType == BookingType.day) {
      dates.add("${_singleDate.year}-${_singleDate.month.toString().padLeft(2, '0')}-${_singleDate.day.toString().padLeft(2, '0')}");
    } else if (_selectedType == BookingType.long) {
      if (_dateRange == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date range.')),
        );
        return;
      }
      DateTime current = _dateRange!.start;
      final end = _dateRange!.end;
      while (!current.isAfter(end)) {
        dates.add("${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}");
        current = current.add(const Duration(days: 1));
      }
    } else {
      if (_scatteredDates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one date.')),
        );
        return;
      }
      for (final date in _scatteredDates) {
        dates.add("${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}");
      }
    }

    final selectedSlotsList = _slots.where((s) => _selectedSlotIds.contains(s['id'])).toList();

    final navigator = Navigator.of(context);
    final result = await navigator.push(
      MaterialPageRoute(
        builder: (context) => OrderPreviewScreen(
          turf: widget.turf,
          token: widget.token!,
          selectedSlotIds: _selectedSlotIds,
          selectedSlots: selectedSlotsList,
          bookingType: _selectedType,
          dates: dates,
        ),
      ),
    );
    if ((result == 'show_bookings' || result == 'show_client_bookings') && mounted) {
      navigator.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final name = widget.turf.name;
    final locationName = widget.turf.locationName;
    final price = widget.turf.priceText;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Turf'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E2022) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.sports_soccer, color: theme.colorScheme.primary, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locationName.isNotEmpty ? locationName : name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (locationName.isNotEmpty &&
                                locationName.trim().toLowerCase() != name.trim().toLowerCase()) ...[
                              const SizedBox(height: 2),
                              Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                            if (widget.turf.locationAddress.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.turf.locationAddress,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              price,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Booking option choice row
              _buildBookingTypeSelector(),
              const SizedBox(height: 24),

              // Dynamic date picker rendering
              _buildDatePickerArea(),
              const SizedBox(height: 32),

              // Slots selection
              Text(
                'Available Slots',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildSlotsSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
          child: ElevatedButton(
            onPressed: _submittingBooking
                ? null
                : (widget.token == null
                    ? () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Login Required'),
                            content: const Text('Please login to book this turf.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please log in from the profile section.')),
                                  );
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    : _submitBooking),
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
                : const Text('Proceed to Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
