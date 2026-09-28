import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import 'core_providers.dart';

/// Help banners closed by the user (one name per screen : 'garden', 'parcel'…), remembered between launches.
final hiddenHelpProvider = NotifierProvider<HiddenHelpNotifier, Set<String>>(HiddenHelpNotifier.new);

class HiddenHelpNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => (ref.read(sharedPreferencesProvider).getStringList(AppConstants.hiddenHelpKey) ?? const []).toSet();

  void setHidden(String screen, bool hidden) {
    state = hidden ? {...state, screen} : ({...state}..remove(screen));
    ref.read(sharedPreferencesProvider).setStringList(AppConstants.hiddenHelpKey, state.toList());
  }
}
