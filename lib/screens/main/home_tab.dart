import 'package:flutter/material.dart';

import '../../models/turf.dart';

/// The "Home" tab: location header, image slider, and the searchable/
/// distance-filtered turf list. Purely presentational — all state
/// (slider images/page, location, turf list) is owned by [MainScreen];
/// `filteredTurfs` arrives already distance-filtered from there.
class HomeTab extends StatelessWidget {
  final String userName;
  final bool sliderLoading;
  final List<dynamic> sliderImages;
  final PageController? sliderPageController;
  final int sliderCurrentPage;
  final bool isLocating;
  final String selectedCity;
  final bool turfsLoading;
  final List<Turf> filteredTurfs;
  final double? selectedLatitude;
  final double? selectedLongitude;
  final double Function(double lat1, double lon1, double lat2, double lon2) calculateDistance;
  final ValueChanged<int> onSliderPageChanged;
  final VoidCallback onOpenCityPicker;
  final Future<void> Function() onRefreshTurfs;
  final void Function(Turf turf) onOpenTurfDetail;

  const HomeTab({
    super.key,
    required this.userName,
    required this.sliderLoading,
    required this.sliderImages,
    required this.sliderPageController,
    required this.sliderCurrentPage,
    required this.isLocating,
    required this.selectedCity,
    required this.turfsLoading,
    required this.filteredTurfs,
    required this.selectedLatitude,
    required this.selectedLongitude,
    required this.calculateDistance,
    required this.onSliderPageChanged,
    required this.onOpenCityPicker,
    required this.onRefreshTurfs,
    required this.onOpenTurfDetail,
  });

  Widget _buildSliderWidget(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (sliderLoading && sliderImages.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2022) : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (sliderImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: sliderPageController,
              onPageChanged: onSliderPageChanged,
              itemCount: sliderImages.length,
              itemBuilder: (context, index) {
                final slide = sliderImages[index];
                return GestureDetector(
                  onTap: () {
                    final linkUrl = slide['link_url'];
                    if (linkUrl != null && linkUrl.toString().isNotEmpty) {
                      // Custom click action
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        slide['image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.broken_image_rounded, size: 48),
                          );
                        },
                      ),
                      // Gradient overlay
                      if (slide['title'] != null && slide['title'].toString().isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Text(
                              slide['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Indicators
          Positioned(
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(sliderImages.length, (index) {
                final isActive = sliderCurrentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 5,
                  width: isActive ? 15 : 5,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurfCard(BuildContext context, Turf turf) {
    final theme = Theme.of(context);
    final name = turf.name;
    final location = '${turf.locationName}, ${turf.locationAddress}';
    final price = turf.priceText;
    final rating = turf.rating;
    final hasRating = turf.hasRating;
    final imageIcon = turf.type == 'Synthetic' ? Icons.grass : Icons.stadium;
    final imageUrl = turf.imageUrl;

    final lat = turf.latitude;
    final lng = turf.longitude;
    String? distanceText;
    if (selectedLatitude != null && selectedLongitude != null && lat != null && lng != null) {
      final dist = calculateDistance(selectedLatitude!, selectedLongitude!, lat, lng);
      distanceText = '${dist.toStringAsFixed(1)} km';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpenTurfDetail(turf),
        child: SizedBox(
          height: 104,
          child: Row(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(imageIcon, size: 32, color: theme.colorScheme.primary),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(imageIcon, size: 32, color: theme.colorScheme.primary),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (distanceText != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• $distanceText',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            price,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (hasRating)
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  rating,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: onOpenCityPicker,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'YOUR LOCATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            isLocating ? 'Locating...' : selectedCity,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Entire home view (Image Slider, Featured Row, and Turf List) scrollable together
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefreshTurfs,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: turfsLoading
                    ? 3
                    : (filteredTurfs.isEmpty ? 3 : filteredTurfs.length + 2),
                itemBuilder: (context, index) {
                  // Index 0: Image Slider
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSliderWidget(context),
                        const SizedBox(height: 24),
                      ],
                    );
                  }

                  // Index 1: Featured Row Title
                  if (index == 1) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Featured Turfs near you',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                            Text(
                              'See All',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }

                  // Index 2+: List Content (Loading, Empty, or Turf Cards)
                  if (turfsLoading) {
                    if (index == 2) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  if (filteredTurfs.isEmpty) {
                    if (index == 2) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.sports_soccer,
                                size: 48,
                                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No approved turfs found',
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  // Render Turf Cards
                  final turfIndex = index - 2;
                  if (turfIndex >= filteredTurfs.length) return const SizedBox.shrink();
                  final turf = filteredTurfs[turfIndex];

                  return _buildTurfCard(context, turf);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
