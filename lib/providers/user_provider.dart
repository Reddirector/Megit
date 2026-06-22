import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final uidProvider = Provider<String?>((ref) => ref.watch(authProvider).user?.uid);
