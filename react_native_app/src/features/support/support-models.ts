import type { MaterialIcons } from '@expo/vector-icons';

/**
 * Ports flutter_app/lib/features/support/presentation/models/support_models.dart.
 * `icon` is the `@expo/vector-icons` `MaterialIcons` name standing in for the
 * Dart `IconData` (same `_outlined` -> plain-name mapping used elsewhere in
 * this port, e.g. `src/app/(app)/(tabs)/_layout.tsx`).
 */
export type SupportTopic = {
  icon: keyof typeof MaterialIcons.glyphMap;
  title: string;
  subtitle: string;
};

export type FaqItem = {
  question: string;
  answer: string;
};
