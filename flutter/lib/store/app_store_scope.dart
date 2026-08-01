// Hand-rolled provider — no new state-management package needed. Rebuilds
// dependents whenever AppStore calls notifyListeners(), same as RN's
// zustand-backed useMesh() re-rendering on store changes.
import 'package:flutter/widgets.dart';
import 'app_store.dart';

class AppStoreScope extends InheritedNotifier<AppStore> {
  const AppStoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStoreScope>();
    assert(scope != null, 'No AppStoreScope found in context');
    return scope!.notifier!;
  }
}
