import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/events.dart';
import '../../../core/providers.dart';
import '../models/abstract_chore.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

@immutable
class ChoresState {
  final List<AbstractChore> chores;
  final bool isLoading;
  final String? error;

  const ChoresState({this.chores = const [], this.isLoading = true, this.error});

  static const _sentinel = Object();

  ChoresState copyWith({List<AbstractChore>? chores, bool? isLoading, Object? error = _sentinel}) {
    return ChoresState(
      chores: chores ?? this.chores,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : (error as String?),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final choresProvider = NotifierProvider<ChoresNotifier, ChoresState>(ChoresNotifier.new);

class ChoresNotifier extends Notifier<ChoresState> {
  @override
  ChoresState build() {
    final eventBus = ref.read(eventBusProvider);
    final sub = eventBus.on<ChoresChangedEvent>().listen(_onChoresChanged);
    ref.onDispose(sub.cancel);
    return const ChoresState();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _reload();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    await _reload();
  }

  Future<void> _reload() async {
    state = state.copyWith(chores: []);
    try {
      final choreManager = ref.read(choreManagerProvider);
      final chores = choreManager.getAvailableChores();
      state = state.copyWith(chores: chores);
    } catch (e, stackTrace) {
      final logger = ref.read(loggerProvider);
      logger.e('Failed to reload chores: $e', error: e, stackTrace: stackTrace);
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  void _onChoresChanged(ChoresChangedEvent event) {
    final logger = ref.read(loggerProvider);
    logger.d('Chores changed for scene: ${event.scene.name}, reloading chores...');
    unawaited(() async {
      try {
        state = state.copyWith(isLoading: true, error: null, chores: []);
        await _reload();
      } finally {
        state = state.copyWith(isLoading: false);
      }
    }());
  }
}
