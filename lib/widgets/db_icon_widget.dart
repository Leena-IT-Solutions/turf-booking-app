import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders icons from the database (keyword, emoji, SVG, or image URL)
/// with fallbacks mapped to database seed and admin definitions.
class DbIconWidget extends StatelessWidget {
  final dynamic item;
  final String? explicitIcon;
  final Color color;
  final double size;

  const DbIconWidget({
    super.key,
    this.item,
    this.explicitIcon,
    required this.color,
    this.size = 18,
  });

  /// Canonical database seed & admin dictionary mapping
  static const Map<String, String> _dbNameIconMap = {
    // Facilities
    'Locker Rooms': 'key',
    'Shower & Washroom': 'shower',
    'Free Parking': 'parking',
    'Water Dispenser': 'water',
    'Night Lighting (Floodlights)': 'light',
    'First Aid Station': 'first-aid',
    'Cafeteria / Canteen': 'coffee',
    'Spectator Seating': 'seating',
    'Waiting Lounge': '🛋️',
    'Wi-Fi Zone': 'wifi',

    // Sports
    'Football (5-a-side)': 'football',
    'Football (7-a-side)': 'football',
    'Box Cricket': 'cricket',
    'Lawn Tennis': 'tennis',
    'Basketball': 'basketball',
    'Volleyball': 'volleyball',
    'Kabaddi': '🤼',
    'Badminton': '🏸',
    'Table Tennis': '🏓',

    // Equipments
    'FIFA Pro Soccer Balls': 'soccer-ball',
    'Colored Training Bibs (Red)': '🔴',
    'Colored Training Bibs (Blue)': '🔵',
    'Tennis Rackets': '🎾',
    'Cricket Bats (English Willow)': 'cricket-bat',
    'Cricket Leather Balls': 'cricket-ball',
    'Cricket Wooden Stumps': 'cricket-stumps',
    'Agility Cones & Ladders': '📐',
    'Basketballs': 'basketball-ball',
    'Volleyballs': '🏐',
    'Goal Post Nets': '🥅',
    'Tennis Balls': 'tennis-ball',
  };

  @override
  Widget build(BuildContext context) {
    String? iconStr = explicitIcon;

    if (iconStr == null || iconStr.isEmpty) {
      if (item is Map) {
        iconStr = item['icon']?.toString();
      }
    }

    if (iconStr == null || iconStr.isEmpty) {
      final name = (item is Map) ? item['name']?.toString() : item?.toString();
      if (name != null) {
        iconStr = _dbNameIconMap[name];
        if (iconStr == null) {
          // Case-insensitive lookup
          for (final entry in _dbNameIconMap.entries) {
            if (entry.key.toLowerCase() == name.trim().toLowerCase()) {
              iconStr = entry.value;
              break;
            }
          }
        }
      }
    }

    return _buildIconContent(iconStr ?? '');
  }

  Widget _buildIconContent(String iconVal) {
    final trimmed = iconVal.trim();
    if (trimmed.isEmpty) {
      return Icon(Icons.check_circle_outline, color: color, size: size);
    }

    // 1. Raw SVG string
    if (trimmed.startsWith('<svg') || trimmed.contains('</svg>')) {
      return SvgPicture.string(
        trimmed,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    // 2. Image URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      if (trimmed.endsWith('.svg')) {
        return SvgPicture.network(
          trimmed,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      }
      return Image.network(trimmed, width: size, height: size);
    }

    // 3. Emoji or Unicode symbol (e.g. 🛋️, 🤼, 🏸, 🏓, 🔴, 🔵, 🎾, 📐, 🏐, 🥅)
    if (!RegExp(r'^[a-zA-Z0-9_\-\s]+$').hasMatch(trimmed)) {
      return Text(
        trimmed,
        style: TextStyle(fontSize: size),
        textAlign: TextAlign.center,
      );
    }

    // 4. Icon keyword identifier matching database definitions
    final lower = trimmed.toLowerCase();
    switch (lower) {
      case 'wifi':
        return Icon(Icons.wifi, color: color, size: size);
      case 'parking':
        return Icon(Icons.local_parking, color: color, size: size);
      case 'shower':
      case 'washroom':
        return Icon(Icons.shower, color: color, size: size);
      case 'water':
        return Icon(Icons.water_drop, color: color, size: size);
      case 'light':
      case 'floodlights':
        return Icon(Icons.lightbulb_outline, color: color, size: size);
      case 'first-aid':
        return Icon(Icons.medical_services_outlined, color: color, size: size);
      case 'coffee':
      case 'cafeteria':
        return Icon(Icons.local_cafe_outlined, color: color, size: size);
      case 'seating':
        return Icon(Icons.event_seat, color: color, size: size);
      case 'key':
      case 'locker':
        return Icon(Icons.vpn_key_outlined, color: color, size: size);
      case 'football':
      case 'soccer-ball':
        return Icon(Icons.sports_soccer, color: color, size: size);
      case 'cricket':
      case 'cricket-bat':
      case 'cricket-ball':
      case 'cricket-stumps':
        return Icon(Icons.sports_cricket, color: color, size: size);
      case 'tennis':
      case 'tennis-ball':
        return Icon(Icons.sports_tennis, color: color, size: size);
      case 'basketball':
      case 'basketball-ball':
        return Icon(Icons.sports_basketball, color: color, size: size);
      case 'volleyball':
      case 'volleyball-ball':
        return Icon(Icons.sports_volleyball, color: color, size: size);
      case 'sun':
      case 'morning':
      case 'afternoon':
        return Icon(Icons.wb_sunny_outlined, color: color, size: size);
      case 'sunset':
      case 'evening':
        return Icon(Icons.wb_twilight, color: color, size: size);
      case 'moon':
      case 'night':
        return Icon(Icons.nightlight_round, color: color, size: size);
      default:
        return Icon(Icons.check_circle_outline, color: color, size: size);
    }
  }
}
