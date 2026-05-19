import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

class TrackOrderScreenFull extends StatelessWidget {
  const TrackOrderScreenFull({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Track Order',
          style: GoogleFonts.epilogue(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Order Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #45782',
                      style: GoogleFonts.epilogue(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'On the way',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildProgressTimeline(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Delivery Person Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppColors.fireSunGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CachedNetworkImage(
                  imageUrl:
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuAFRHg36EQATUqDhYD94R_K05G_f_-4ocNsdVBQUVTX8xvKbpdmSknU7GmZePTgv4lBF85k0RDyrmnlfs2PK53uCy3GJCX-D--qbu1fE71RUty6lSxYRFbaGWOOlbJXVqBEcr0UyXTpyWdZPmjRyEUF1OHHnMx-xCvUUimbd_auXDxH-k66vULm46he9xSs-oD00XaZzS3nF9H6yAXrF6_RTe3YZfKuK56TfbmvM9woXHeOrwZGm0mMP7mewgHD325vsNshlQvqaSTD',
                  imageBuilder: (context, imageProvider) =>
                      CircleAvatar(
                    backgroundImage: imageProvider,
                    radius: 35,
                  ),
                  placeholder: (context, url) =>
                      const CircleAvatar(radius: 35),
                  errorWidget: (context, url, error) =>
                      const CircleAvatar(radius: 35),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Partner',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white.withOpacityValue(0.8),
                        ),
                      ),
                      Text(
                        'Yusuf Adeyemi',
                        style: GoogleFonts.epilogue(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 14,
                              color: Colors.white),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '4.9',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Estimated Arrival
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Estimated Arrival',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  '12 minutes',
                  style: GoogleFonts.epilogue(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimeline() {
    return Column(
      children: [
        _buildTimelineStep('Order Confirmed', true, true),
        _buildTimelineStep('Preparing', true, true),
        _buildTimelineStep('Out for Delivery', true, false),
        _buildTimelineStep('Delivered', false, false),
      ],
    );
  }

  Widget _buildTimelineStep(String label, bool isCompleted, bool hasConnector) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.primary : AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(50),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (hasConnector)
              Container(
                width: 2,
                height: 40,
                color: AppColors.primary,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.lg),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isCompleted
                ? AppColors.onSurface
                : AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
