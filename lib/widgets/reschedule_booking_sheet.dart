import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';

class RescheduleBookingSheet extends StatefulWidget {
  final Booking bookingDate;
  final String? token;
  final VoidCallback? onSuccess;

  const RescheduleBookingSheet({
    super.key,
    required this.bookingDate,
    this.token,
    this.onSuccess,
  });

  @override
  State<RescheduleBookingSheet> createState() => _RescheduleBookingSheetState();
}

class _RescheduleBookingSheetState extends State<RescheduleBookingSheet> {
  late DateTime _selectedDate;
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _formatDateRaw(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _formatDisplayDate(DateTime d) =>
      "${_weekdays[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}";

  bool _isLoadingSlots = false;
  String? _slotsError;
  List<RescheduleSlot> _slots = [];
  final Set<int> _selectedSlotIds = {};

  bool _isLoadingPreview = false;
  ReschedulePreview? _preview;
  String? _previewError;

  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default to tomorrow or today if early
    final now = DateTime.now();
    _selectedDate = now.add(const Duration(days: 1));
    _fetchSlots();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchSlots() async {
    setState(() {
      _isLoadingSlots = true;
      _slotsError = null;
      _selectedSlotIds.clear();
      _preview = null;
      _previewError = null;
    });

    final dateStr = _formatDateRaw(_selectedDate);
    final res = await ApiService.getRescheduleSlots(
      widget.bookingDate.id,
      dateStr,
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final List<RescheduleSlot> slots = res['slots'] as List<RescheduleSlot>;
      setState(() {
        _slots = slots;
        _isLoadingSlots = false;
      });
    } else {
      setState(() {
        _slotsError = res['message'] ?? 'Could not load slots for this date.';
        _isLoadingSlots = false;
      });
    }
  }

  Future<void> _updatePreview() async {
    if (_selectedSlotIds.isEmpty) {
      setState(() {
        _preview = null;
        _previewError = null;
      });
      return;
    }

    setState(() {
      _isLoadingPreview = true;
      _previewError = null;
    });

    final dateStr = _formatDateRaw(_selectedDate);
    final res = await ApiService.previewReschedule(
      widget.bookingDate.id,
      dateStr,
      _selectedSlotIds.toList(),
      token: widget.token,
    );

    if (!mounted) return;

    if (res['success'] == true && res['preview'] is ReschedulePreview) {
      setState(() {
        _preview = res['preview'] as ReschedulePreview;
        _isLoadingPreview = false;
      });
    } else {
      setState(() {
        _previewError = res['message'] ?? 'Could not calculate price preview.';
        _isLoadingPreview = false;
      });
    }
  }

  void _onSlotTapped(RescheduleSlot slot) {
    if (!slot.isAvailable) return;

    setState(() {
      if (_selectedSlotIds.contains(slot.id)) {
        _selectedSlotIds.remove(slot.id);
      } else {
        _selectedSlotIds.add(slot.id);
      }
    });

    _updatePreview();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchSlots();
    }
  }

  Future<void> _confirmReschedule() async {
    if (_selectedSlotIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one slot for the new session.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final dateStr = _formatDateRaw(_selectedDate);
    final res = await ApiService.rescheduleBooking(
      widget.bookingDate.id,
      dateStr,
      _selectedSlotIds.toList(),
      reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
      token: widget.token,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Booking rescheduled successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop(true);
      widget.onSuccess?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to reschedule booking.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_calendar_rounded, color: theme.colorScheme.primary, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Reschedule Session',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.bookingDate.turfName} • Current: ${widget.bookingDate.bookingDate}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reschedule policy badge
                  if (widget.bookingDate.maxReschedules > 1)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reschedule ${widget.bookingDate.rescheduleCount} of ${widget.bookingDate.maxReschedules} used',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Date Picker Card
                  Text(
                    'Select New Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formatDisplayDate(_selectedDate),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Change',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Slots Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select New Slot(s)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (_selectedSlotIds.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedSlotIds.length} selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_isLoadingSlots)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_slotsError != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _slotsError!,
                              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: _fetchSlots,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_slots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      child: Text(
                        'No slots configured for this date.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _slots.map((slot) {
                        final isSelected = _selectedSlotIds.contains(slot.id);
                        final isAvail = slot.isAvailable;

                        Color bg;
                        Color border;
                        Color textCol;

                        if (isSelected) {
                          bg = theme.colorScheme.primary;
                          border = theme.colorScheme.primary;
                          textCol = Colors.white;
                        } else if (!isAvail) {
                          bg = Colors.grey.shade100;
                          border = Colors.grey.shade300;
                          textCol = Colors.grey.shade400;
                        } else {
                          bg = Colors.white;
                          border = Colors.grey.shade300;
                          textCol = Colors.grey.shade800;
                        }

                        return InkWell(
                          onTap: isAvail ? () => _onSlotTapped(slot) : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: (MediaQuery.of(context).size.width - 56) / 2,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: border, width: isSelected ? 1.5 : 1.0),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 13,
                                      color: isSelected ? Colors.white : (isAvail ? theme.colorScheme.primary : Colors.grey.shade400),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        slot.timeRange,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: textCol,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '₹${slot.price.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? Colors.white70 : Colors.grey.shade700,
                                      ),
                                    ),
                                    if (!isAvail)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          slot.isCurrentSlot ? 'Current' : 'Booked',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),

                  // Price Difference Preview Card
                  if (_isLoadingPreview)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Calculating price breakdown...', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else if (_previewError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _previewError!,
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_preview != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              const Text(
                                'Price Comparison',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Original Session Price:', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                              Text('₹${_preview!.oldAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('New Slots Price (${_preview!.newSlotCount} slot${_preview!.newSlotCount == 1 ? '' : 's'}):', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                              Text('₹${_preview!.newAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1),
                          ),

                          // Direction badge
                          if (_preview!.direction == 'extra_charge')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline_rounded, color: Colors.amber.shade900, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Extra Cash to Collect: ₹${_preview!.difference.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.amber.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Collect directly from customer at venue.',
                                          style: TextStyle(color: Colors.amber.shade900, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_preview!.direction == 'refund')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF047857), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Refund to Customer: ₹${_preview!.difference.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Color(0xFF047857),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _preview!.refundChannel == 'gateway'
                                              ? 'Refund credited via payment gateway.'
                                              : 'Disburse via Cash / Offline.',
                                          style: const TextStyle(color: Color(0xFF065F46), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, color: Colors.blue.shade700, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'No price difference. Booking total remains unchanged.',
                                      style: TextStyle(color: Colors.blue.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Optional Reason
                  Text(
                    'Reason for Rescheduling (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Customer requested evening slot',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + systemBottomPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || _selectedSlotIds.isEmpty) ? null : _confirmReschedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Confirm Reschedule',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
