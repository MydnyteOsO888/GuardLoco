import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

final authActionsProvider = Provider<AuthNotifier>((ref) {
  return ref.read(authProvider.notifier);
});
