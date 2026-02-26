import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/providers/auth_provider.dart';
import 'dart:async';

class AuthController extends AsyncNotifier<void> {
  late final AuthRepository _authRepository;

  @override
  FutureOr<void> build() {
    _authRepository = ref.watch(authRepositoryProvider);
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => 
      _authRepository.signInWithEmailAndPassword(email: email, password: password)
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.signInWithGoogle());
  }

  Future<void> signUpWithEmail(String email, String password, {String displayName = ''}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() =>
      _authRepository.createUserWithEmailAndPassword(email: email, password: password, displayName: displayName)
    );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});
