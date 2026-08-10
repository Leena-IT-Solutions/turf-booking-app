import 'package:flutter/material.dart';

class MultiDatePickerDialog extends StatefulWidget {
  final List<DateTime> initialDates;

  const MultiDatePickerDialog({super.key, required this.initialDates});

  @override
  State<MultiDatePickerDialog> createState() => _MultiDatePickerDialogState();
}

class _MultiDatePickerDialogState extends State<MultiDatePickerDialog> {
  late List<DateTime> _selectedDates;
  late int _displayYear;
  late int _displayMonth;

  final List<String> _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDates = List.from(widget.initialDates);
    final now = DateTime.now();
    _displayYear = now.year;
    _displayMonth = now.month;
  }

  bool _isSelected(DateTime date) {
    return _selectedDates.any((d) => DateUtils.isSameDay(d, date));
  }

  void _toggleDate(DateTime date) {
    setState(() {
      if (_isSelected(date)) {
        _selectedDates.removeWhere((d) => DateUtils.isSameDay(d, date));
      } else {
        _selectedDates.add(date);
        _selectedDates.sort((a, b) => a.compareTo(b));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final firstDayOfMonth = DateTime(_displayYear, _displayMonth, 1);
    final daysInMonth = DateTime(_displayYear, _displayMonth + 1, 0).day;
    final startOffset = firstDayOfMonth.weekday % 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final prevEnabled = _displayYear > now.year || (_displayYear == now.year && _displayMonth > now.month);

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: prevEnabled
                      ? () {
                          setState(() {
                            if (_displayMonth == 1) {
                              _displayMonth = 12;
                              _displayYear--;
                            } else {
                              _displayMonth--;
                            }
                          });
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${_months[_displayMonth - 1]} $_displayYear',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_displayMonth == 12) {
                        _displayMonth = 1;
                        _displayYear++;
                      } else {
                        _displayMonth++;
                      }
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _weekdays.map((w) {
                return SizedBox(
                  width: 32,
                  child: Text(
                    w,
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: startOffset + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                if (index < startOffset) {
                  return const SizedBox.shrink();
                }

                final dayNum = index - startOffset + 1;
                final date = DateTime(_displayYear, _displayMonth, dayNum);
                final isPast = date.isBefore(today);
                final selected = _isSelected(date);

                return InkWell(
                  onTap: isPast ? null : () => _toggleDate(date),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? theme.colorScheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? Colors.white
                            : (isPast
                                ? Colors.grey[400]
                                : (isDark ? Colors.white : Colors.black87)),
                        fontWeight: selected || date == today ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
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
          onPressed: () {
            Navigator.pop(context, _selectedDates);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
