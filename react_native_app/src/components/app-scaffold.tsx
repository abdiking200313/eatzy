import { MaterialIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import type { ReactNode } from 'react';
import { Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useSemanticColors } from '@/hooks/use-semantic-colors';

export type AppScaffoldProps = {
  title: string;
  children: ReactNode;
  showBackButton?: boolean;
  actions?: ReactNode;
  floatingActionButton?: ReactNode;
  bottomBar?: ReactNode;
  /**
   * Advisory only. Flutter's `Scaffold.resizeToAvoidBottomInset` shrinks the
   * whole screen above the keyboard; there is no 1:1 React Native
   * equivalent at this component's level. When a screen needs that
   * behavior, wrap its own `children` in a `KeyboardAvoidingView` at the
   * call site instead.
   */
  resizeToAvoidBottomInset?: boolean;
};

/**
 * Ports flutter_app/lib/widgets/app_scaffold.dart's `AppScaffold`: a
 * standard screen shell with the Zivo surface background, an opinionated
 * header title, and an optional back button.
 *
 * Unlike the Flutter `Scaffold`/`AppBar`, this renders its own header
 * unconditionally rather than relying on Expo Router's native stack header
 * — the Flutter widget always draws its own `AppBar` regardless of
 * `go_router`'s navigation chrome, so this does the same.
 *
 * `showBackButton` is taken as the single source of truth for whether a
 * back button shows. The Flutter `AppBar` also has `automaticallyImplyLeading`
 * (on by default), which can show a back button even when `leading` is
 * null if the current route can pop — that GoRouter-stack-dependent nuance
 * is not reproduced here.
 */
export function AppScaffold({
  title,
  children,
  showBackButton = false,
  actions,
  floatingActionButton,
  bottomBar,
}: AppScaffoldProps) {
  const colors = useSemanticColors();

  const handleBack = () => {
    if (router.canGoBack()) {
      router.back();
      return;
    }
    // TODO(rn-logic-agent): point this at the real main-app tab route once
    // one exists (mirrors `AppRoutes.mainApp` = '/app' in
    // flutter_app/lib/app/app_routes.dart's `context.go(AppRoutes.mainApp)`
    // fallback). '/' is a placeholder until that route is wired up.
    router.replace('/');
  };

  return (
    <View style={{ backgroundColor: colors.bg }} className="flex-1">
      <SafeAreaView edges={['top']} className="flex-1">
        <View
          style={{ height: 64 }}
          className="flex-row items-center border-b border-border px-x2">
          {showBackButton && (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Back"
              onPress={handleBack}
              className="h-x10 w-x10 items-center justify-center active:opacity-70">
              <MaterialIcons name="arrow-back" size={24} color={colors.text} />
            </Pressable>
          )}
          <Text
            style={{ marginLeft: showBackButton ? 0 : 16 }}
            className="flex-1 text-textXl font-outfitBold text-text"
            numberOfLines={1}>
            {title}
          </Text>
          {actions && <View className="flex-row items-center">{actions}</View>}
        </View>

        <View className="flex-1">{children}</View>

        {floatingActionButton && (
          <View pointerEvents="box-none" className="absolute bottom-x5 right-x5">
            {floatingActionButton}
          </View>
        )}
      </SafeAreaView>
      {bottomBar}
    </View>
  );
}
