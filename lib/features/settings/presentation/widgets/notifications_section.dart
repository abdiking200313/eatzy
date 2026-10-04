import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../data/notification_preferences_repository.dart';
import 'toggle_card.dart';

/// The Settings screen's "Notifications" section: the section title plus
/// the Push / Email / Promotional / Order-updates toggle rows, grouped in
/// one shared [OutlinedCard] with internal dividers.
///
/// Pushing a notification preference change up to the Settings screen
/// (rather than owning the value here) keeps this widget a plain, stateless
/// presenter — persistence and the push-permission dance stay with the
/// screen's existing `_setPushNotifications`/`_updatePreferences`.
class NotificationsSection extends StatelessWidget {
  const NotificationsSection({
    super.key,
    required this.preferences,
    required this.onPushNotificationsChanged,
    required this.onEmailNotificationsChanged,
    required this.onPromotionalEmailsChanged,
    required this.onOrderUpdatesChanged,
  });

  final NotificationPreferences preferences;
  final ValueChanged<bool> onPushNotificationsChanged;
  final ValueChanged<bool> onEmailNotificationsChanged;
  final ValueChanged<bool> onPromotionalEmailsChanged;
  final ValueChanged<bool> onOrderUpdatesChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notifications', style: TwText.sectionTitle),
        const SizedBox(height: TwSpacing.headerToContent),
        OutlinedCard(
          padding: EdgeInsets.zero,
          borderRadius: TwRadius.card,
          child: Column(
            children: [
              ToggleCard(
                title: 'Push Notifications',
                subtitle: 'Get notifications about your orders',
                value: preferences.pushNotifications,
                onChanged: onPushNotificationsChanged,
              ),
              const Divider(height: 1),
              ToggleCard(
                title: 'Email Notifications',
                subtitle: 'Receive updates via email',
                value: preferences.emailNotifications,
                onChanged: onEmailNotificationsChanged,
              ),
              const Divider(height: 1),
              ToggleCard(
                title: 'Promotional Emails',
                subtitle: 'Get exclusive deals and offers',
                value: preferences.promotionalEmails,
                onChanged: onPromotionalEmailsChanged,
              ),
              const Divider(height: 1),
              ToggleCard(
                title: 'Order Updates',
                subtitle: 'Receive order status updates',
                value: preferences.orderUpdates,
                onChanged: onOrderUpdatesChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
