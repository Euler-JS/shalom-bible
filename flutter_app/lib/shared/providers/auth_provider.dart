import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/remote/api_client.dart';
import '../../core/constants/app_constants.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage = const FlutterSecureStorage();

  AuthNotifier() : super(const AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final token = await ApiClient.instance.getToken();
    if (token == null) return;

    final userJson = await _storage.read(key: AppConstants.userDataKey);
    if (userJson != null) {
      try {
        final user = UserModel.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
        state = state.copyWith(user: user);
      } catch (_) {}
    }

    // Refresh from server
    try {
      final data = await ApiClient.instance.getProfile();
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await _saveUser(user);
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  Future<void> _saveUser(UserModel user) async {
    await _storage.write(
      key: AppConstants.userDataKey,
      value: jsonEncode(user.toJson()),
    );
  }

  Future<bool> register({
    required String email,
    required String password,
    String? name,
    String language = 'pt',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ApiClient.instance.register(
        email: email,
        password: password,
        name: name,
        language: language,
      );
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await ApiClient.instance.saveToken(token);
      await _saveUser(user);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ApiClient.instance.login(
        email: email,
        password: password,
      );
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await ApiClient.instance.saveToken(token);
      await _saveUser(user);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<void> logout() async {
    await ApiClient.instance.clearToken();
    await _storage.delete(key: AppConstants.userDataKey);
    state = const AuthState();
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ApiClient.instance.deleteAccount();
      await ApiClient.instance.clearToken();
      await _storage.delete(key: AppConstants.userDataKey);
      state = const AuthState();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  String _parseError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('409')) return 'Este email já está registado.';
      if (msg.contains('401')) return 'Email ou senha incorrectos.';
      if (msg.contains('delete')) return 'Não foi possível eliminar a conta.';
      if (msg.contains('network') || msg.contains('connection')) {
        return 'Sem ligação à internet.';
      }
    }
    return 'Algo correu mal. Tenta novamente.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
