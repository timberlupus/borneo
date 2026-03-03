import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

@immutable
class ChoreSummaryState {
  final bool isActive;
  final bool isBusy;
  final String? error;

  const ChoreSummaryState({this.isActive = false, this.isBusy = false, this.error});

  static const _sentinel = Object();

  ChoreSummaryState copyWith({bool? isActive, bool? isBusy, Object? error = _sentinel}) {
    return ChoreSummaryState(
      isActive: isActive ?? this.isActive,
      isBusy: isBusy ?? this.isBusy,
      error: error == _sentinel ? this.error : (error as String?),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider  (family key = choreId)
// ---------------------------------------------------------------------------

/// Factory that creates a [ChoreSummaryNotifier] for the given choreId.
final choreSummaryProvider = NotifierProvider.family<ChoreSummaryNotifier, ChoreSummaryState, String>(
  (arg) => ChoreSummaryNotifier(arg),
);

class ChoreSummaryNotifier extends Notifier<ChoreSummaryState> {
  /// The chore ID passed as the family argument.
  final String choreId;

  ChoreSummaryNotifier(this.choreId);

  @override
  ChoreSummaryState build() => const ChoreSummaryState();

  Future<void> init() async {
    final choreManager = ref.read(choreManagerProvider);
    final logger = ref.read(loggerProvider);
    try {
      final isActive = await choreManager.hasHistoryForChore(choreId);
      state = state.copyWith(isActive: isActive);
    } catch (e, st) {
      logger.e('Failed to initialize chore state', error: e, stackTrace: st);
    }
  }

  Future<void> executeChore() async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true, error: null);
    final choreManager = ref.read(choreManagerProvider);
    final notification = ref.read(appNotificationServiceProvider);
    final logger = ref.read(loggerProvider);
    try {
      await choreManager.executeChore(choreId);
      state = state.copyWith(isActive: true);
    } catch (e, st) {
      logger.e(e.toString(), error: e, stackTrace: st);
      notification.showError('Chore execution failed', body: e.toString());
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> undoChore() async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true, error: null);
    final choreManager = ref.read(choreManagerProvider);
    final notification = ref.read(appNotificationServiceProvider);
    final logger = ref.read(loggerProvider);
    try {
      await choreManager.undoChore(choreId);
      state = state.copyWith(isActive: false);
    } catch (e, st) {
      logger.e(e.toString(), error: e, stackTrace: st);
      notification.showError('Undo chore failed', body: e.toString());
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }
}
