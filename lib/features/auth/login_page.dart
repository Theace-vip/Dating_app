import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/shared/server_host.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _isRegister = false; // false = đăng nhập, true = đăng ký

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _submit() async {
    if (!await ensureOnline(context, ref)) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      _showError('Vui lòng nhập email hợp lệ');
      return;
    }
    if (password.length < 8) {
      _showError('Mật khẩu cần ít nhất 8 ký tự');
      return;
    }
    if (_isRegister && name.length < 2) {
      _showError('Vui lòng nhập tên (tối thiểu 2 ký tự)');
      return;
    }

    setState(() => _loading = true);
    final error = _isRegister
        ? await ref.read(authProvider.notifier).register(email, password, name)
        : await ref.read(authProvider.notifier).login(email, password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      // Lỗi kết nối -> mở ngay dialog đặt máy chủ (thường do chưa đặt IP/tunnel
      // hoặc server/tunnel chưa chạy)
      if (error.contains('Không thể kết nối máy chủ') && mounted) {
        showServerHostDialog(
          context,
          ref,
          hint:
              'App đang trỏ tới ${AppConfig.apiBaseUrl} mà không kết nối được. '
              'Đảm bảo ket_noi_internet.bat (hoặc server) đang chạy, rồi dán URL/IP mới.',
        );
      } else {
        _showError(error);
      }
    }
    // Thành công -> router tự điều hướng (cập nhật auth state)
  }

  void _soon() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Tính năng sắp ra mắt')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.primaryGradient),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      const Text('💜', style: TextStyle(fontSize: 72)),
                      const SizedBox(height: 12),
                      const Text(
                        'SoulMate',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tìm người tâm giao của bạn',
                        style: TextStyle(fontSize: 15, color: Colors.white70),
                      ),
                      const SizedBox(height: 36),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            if (_isRegister) ...[
                              AppTextField(
                                hint: 'Tên hiển thị',
                                controller: _nameController,
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            AppTextField(
                              hint: 'Email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              hint: 'Mật khẩu (8+ ký tự, có chữ và số)',
                              controller: _passwordController,
                              obscure: _obscure,
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: AppColors.primary,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _loading
                                ? const LoadingWidget()
                                : AppButton(
                                    label: _isRegister
                                        ? 'Đăng ký'
                                        : 'Đăng nhập',
                                    onPressed: _submit,
                                  ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(
                                      () => _isRegister = !_isRegister,
                                    ),
                              child: Text(
                                _isRegister
                                    ? 'Đã có tài khoản? Đăng nhập'
                                    : 'Chưa có tài khoản? Đăng ký ngay',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: const [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'HOẶC',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    label: 'SĐT (OTP)',
                                    isGradient: false,
                                    outline: true,
                                    onPressed: _soon,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AppButton(
                                    label: 'Google',
                                    isGradient: false,
                                    outline: true,
                                    onPressed: _soon,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Đặt địa chỉ máy chủ NGAY TẠI MÀN NÀY (chưa đăng nhập vẫn đặt được)
                      TextButton.icon(
                        onPressed: () => showServerHostDialog(context, ref),
                        icon: const Icon(
                          Icons.dns_outlined,
                          size: 16,
                          color: Colors.white70,
                        ),
                        label: Text(
                          'Máy chủ: ${AppConfig.serverHost}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Text(
                        'Bằng việc tiếp tục, bạn đồng ý với Điều khoản & Quyền riêng tư',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
