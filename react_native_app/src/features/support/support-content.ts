import type { FaqItem, SupportTopic } from './support-models';

/**
 * The static lists from flutter_app/lib/features/support/presentation/support_screen.dart
 * (`_helpTopics`, `_contactOptions`, `_faqItems`), copied verbatim --
 * including the placeholder phone number, which Flutter also ships as-is.
 */
export const HELP_TOPICS: readonly SupportTopic[] = [
  { icon: 'shopping-bag', title: 'Orders & Delivery', subtitle: 'Track orders, delivery issues' },
  { icon: 'payment', title: 'Payment', subtitle: 'Pay on delivery, refunds' },
  { icon: 'restaurant', title: 'Restaurants & Food', subtitle: 'Menu, allergies, restaurant info' },
  { icon: 'account-circle', title: 'Account', subtitle: 'Profile, login, passwords' },
];

export const CONTACT_OPTIONS: readonly SupportTopic[] = [
  { icon: 'mail-outline', title: 'Email Us', subtitle: 'support@zivo.com' },
  { icon: 'phone', title: 'Call Us', subtitle: '+234 XXX XXXX XXXX' },
  { icon: 'chat', title: 'Live Chat', subtitle: 'Chat with our team 9AM - 9PM' },
];

export const FAQ_ITEMS: readonly FaqItem[] = [
  {
    question: 'How do I track my order?',
    answer:
      "You can track your order in real-time from the Track Order section. You'll receive updates at each stage.",
  },
  {
    question: 'What if my food is late?',
    answer: 'If your order is delayed, contact our support team for immediate assistance and compensation.',
  },
  {
    question: 'Can I change my order?',
    answer: 'You can modify your order up to 2 minutes after placing it.',
  },
];
