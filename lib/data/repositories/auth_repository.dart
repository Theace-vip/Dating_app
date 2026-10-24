import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/models/models.dart';

// ===== Auth State =====
enum AuthStatus {
  restoring, // đang khôi phục phiên đăng nhập từ secure storage
  authenticated,
  unauthenticated,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;

  const AuthState({this.status = AuthStatus.restoring, this.user});

  bool get isLoggedIn => status == AuthStatus.authenticated;
  bool get isRestoring => status == AuthStatus.restoring;
  bool get profileCompleted => user?.profileCompleted ?? false;

  AuthState copyWith({AuthStatus? status, UserModel? user}) => AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
      );
}

/// Auth THẬT: email + mật khẩu gọi API backend, token lưu trong
/// FlutterSecureStorage, tự khôi phục phiên khi mở app.
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    _api.onSessionExpired = sessionExpired;
    restore();
  }

  /// Khôi phục phiên đăng nhập khi mở app (không cần nhập lại mật khẩu).
  Future<void> restore() async {
    try {
      await _api.loadTokens();
      if (!_api.hasSession) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final me = await _api.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: me.user);
    } catch (_) {
      await _api.clearSession();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Trả về null nếu thành công, ngược lại trả về thông báo lỗi (tiếng Việt).
  Future<String?> login(String email, String password) async {
    try {
      final result = await _api.login(email, password);
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể đăng nhập — kiểm tra kết nối mạng';
    }
  }

  Future<String?> register(String email, String password, String name) async {
    try {
      final result = await _api.register(email, password, name);
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể đăng ký — kiểm tra kết nối mạng';
    }
  }

  Future<void> logout() async {
    try {
      await _api.logoutOnServer();
    } catch (_) {
      // thu hồi local vẫn chạy
    }
    await _api.clearSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Ép kết thúc trạng thái chờ (dùng khi restore treo quá lâu).
  void forceStopRestore() {
    if (state.isRestoring) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Phiên hết hạn (refresh token không còn hiệu lực) -> về màn đăng nhập.
  void sessionExpired() {
    if (state.isLoggedIn) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Lưu hồ sơ (setup lần đầu hoặc chỉnh sửa) lên server.
  Future<String?> completeProfile({
    required String name,
    required String avatar,
    required int age,
    required Gender gender,
    String? bio,
    required List<String> tags,
  }) async {
    try {
      final user = await _api.updateMe({
        'name': name,
        'avatar': avatar,
        'age': age,
        'gender': gender.name,
        'bio': bio ?? '',
        'tags': tags,
        'profileCompleted': true,
      });
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể lưu hồ sơ — kiểm tra kết nối mạng';
    }
  }

  /// Đổi mật khẩu: server thu hồi phiên cũ, trả token mới (đã lưu).
  Future<String?> changePassword(
      String currentPassword, String newPassword) async {
    try {
      await _api.changePassword(currentPassword, newPassword);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể đổi mật khẩu — kiểm tra kết nối';
    }
  }

  /// Cập nhật số dư khi server báo thay đổi ví (gửi quà...).
  void applyWallet(int coins, int diamonds) {
    final u = state.user;
    if (u == null) return;
    state = state.copyWith(user: u.copyWith(coins: coins, diamonds: diamonds));
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(apiClientProvider)),
);

// ===== User (current) helper =====
final currentUserProvider = Provider<UserModel>((ref) {
  return ref.watch(authProvider).user ??
      const UserModel(
        id: 'u_guest',
        name: 'Khách',
        avatar: '🙂',
        gender: Gender.other,
        age: 18,
      );
});
