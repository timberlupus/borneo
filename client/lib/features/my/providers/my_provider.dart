import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/view_models/base_view_model.dart';

/// Simple view model currently used by the main "My" tab.  Historically this
/// was created via Provider in `main_screen.dart`.  As part of the Riverpod
/// migration we expose it through an application provider so that consumers
/// can obtain it with `ref.watch(myViewModelProvider)` instead of relying on
/// the legacy `provider` package.
///
/// The existing class remains largely unchanged; in the early migration phase
/// the provider will be *overridden* from the widget tree in order to supply
/// the correct `GettextLocalizations` instance.  Once all consumers are
/// converted the old `ChangeNotifierProvider` can be removed completely.

class MyViewModel extends BaseViewModel {
  MyViewModel({required super.gt});

  @override
  void notifyAppError(String message, {Object? error, StackTrace? stackTrace}) {}
}

/// Riverpod provider for [MyViewModel].  By default this throws an
/// [UnimplementedError]; consumers (typically the root `MainScreen`) must
/// override it with a real instance that passes in the current
/// `GettextLocalizations`.
final myViewModelProvider = Provider<MyViewModel>((ref) {
  throw UnimplementedError('myViewModelProvider must be overridden');
});
