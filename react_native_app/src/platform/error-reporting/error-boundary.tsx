/**
 * Root error boundary (issue #351): catches a render error anywhere below
 * it in the tree and shows `ErrorFallbackView`
 * (`@/components/error-fallback.tsx`, ported from
 * `flutter_app/lib/widgets/error_fallback.dart`) instead of a blank screen,
 * while reporting the error through `ErrorReporting.instance`
 * (`./error-reporter.ts`) the same way every other global error hook does.
 *
 * Lives alongside the rest of this app's error-reporting wiring (not under
 * `src/components/`) because it is the global error hook itself -- it reads
 * `ErrorReporting.instance` directly, the same reason `error-reporter.ts`
 * and `crashlytics-error-reporter.ts` live here.
 *
 * Must be a class component -- React has no hook-based equivalent of
 * `getDerivedStateFromError`/`componentDidCatch`.
 */
import { Component, type ErrorInfo, type PropsWithChildren, type ReactNode } from 'react';

import { ErrorFallbackView } from '@/components/error-fallback';

import { ErrorReporting } from './error-reporter';

interface ErrorBoundaryState {
  hasError: boolean;
}

export class ErrorBoundary extends Component<PropsWithChildren, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false };

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    // Prefer the error's own stack; React's `componentStack` (which subtree
    // failed) is still useful context when a non-Error value was thrown and
    // has none.
    ErrorReporting.instance.reportError(error, error.stack ?? errorInfo.componentStack ?? undefined, 'ErrorBoundary');
  }

  render(): ReactNode {
    if (this.state.hasError) {
      return <ErrorFallbackView />;
    }
    return this.props.children;
  }
}
