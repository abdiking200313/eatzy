/**
 * Ports `flutter_app/lib/features/profile/presentation/models/profile_models.dart`'s
 * `ProfileOption` (issue #399 / P8-03).
 */
import type { MaterialIcons } from '@expo/vector-icons';
import type { Href } from 'expo-router';
import type { ComponentProps } from 'react';

export type ProfileOptionIcon = ComponentProps<typeof MaterialIcons>['name'];

export interface ProfileOption {
  title: string;
  icon: ProfileOptionIcon;
  /** Where tapping the row navigates; `undefined` renders a non-interactive row. */
  route?: Href;
  trailingText?: string;
}
