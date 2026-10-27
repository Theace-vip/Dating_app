import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/shared/server_host.dart';

/// Màn hình Đăng nhập / Đăng ký thiết kế hiện đại, lãng mạn:
/// - Tông màu Sunset Gradient hồng cam rực rỡ đặc trưng (#FD297B -> #FF5864 -> #FF655B)
/// - Logo Trái tim tình yêu sắc nét, tối giản, hiện đại
/// - Nút bấm và Input dạng viên thuốc (Pill shape) thanh thoát
/// - Input nền trắng tương phản cao, dễ nhìn 100%
/// - Tối ưu bố cục, không bị tràn màn hình (Overflow) trên mọi thiết bị
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
  bool _isRegister = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }


  Future<void> _submit() async {
    if (!await ensureOnline(context, ref)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      _showError('Vui lòng nhập địa chỉ email hợp lệ');
      return;
    }
    if (password.length < 8) {
      _showError('Mật khẩu cần tối thiểu 8 ký tự');
      return;
    }
    if (_isRegister && name.length < 2) {
      _showError('Tên hiển thị cần tối thiểu 2 ký tự');
      return;
    }

    setState(() => _loading = true);
    final error = _isRegister
        ? await ref.read(authProvider.notifier).register(email, password, name)
        : await ref.read(authProvider.notifier).login(email, password);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      if (error.contains('Không thể kết nối máy chủ') && mounted) {
        showServerHostDialog(
          context,
          ref,
          hint: 'App đang trỏ tới ${AppConfig.apiBaseUrl} nhưng không kết nối được. '
              'Hãy kiểm tra lại server hoặc đổi địa chỉ.',
        );
      } else {
        _showError(error);
      }
    }
  }

  void _soon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tính năng đang được tích hợp'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // Gradient hoàng hôn kinh điển phong cách Tinder
          gradient: LinearGradient(
            colors: [
              Color(0xFFFD297B),
              Color(0xFFFF5864),
              Color(0xFFFF655B),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // Tinder-Style Flame / Heart Logo
                  _buildTinderLogo(),

                  const SizedBox(height: 8),

                  // Brand Name phong cách Tinder
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'soul',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'mate',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 34,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _isRegister ? 'Bắt đầu quẹt và ghép đôi ngay' : 'Tìm kiếm nửa kia của bạn',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Tab switcher Đăng nhập / Đăng ký tối giản kiểu Tinder
                  _buildTinderTabSwitcher(),

                  const SizedBox(height: 20),

                  // Các ô nhập liệu phong cách Pill trong suốt cao cấp
                  if (_isRegister) ...[
                    _buildTinderInputField(
                      controller: _nameController,
                      hintText: 'Tên của bạn',
                      icon: Icons.person_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                  ],

                  _buildTinderInputField(
                    controller: _emailController,
                    hintText: 'Email của bạn',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 14),

                  _buildTinderInputField(
                    controller: _passwordController,
                    hintText: 'Mật khẩu (8+ ký tự)',
                    icon: Icons.lock_rounded,
                    obscureText: _obscure,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF757575),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Nút hành động chính (Pill Button màu trắng chữ gradient - Signature Tinder)
                  _buildTinderButton(),

                  const SizedBox(height: 18),

                  // Divider "HOẶC"
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.3),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'HOẶC',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.3),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Nút mạng xã hội dạng Pill thanh mảnh
                  Row(
                    children: [
                      Expanded(
                        child: _buildSocialPill(
                          icon: _buildGoogleIcon(),
                          label: 'Google',
                          onTap: _soon,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSocialPill(
                          icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                          label: 'Số điện thoại',
                          onTap: _soon,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const SizedBox(height: 12),

                  // Badge máy chủ thu gọn
                  _buildServerBadge(),

                  const SizedBox(height: 10),

                  // Điều khoản
                  Text(
                    'Bằng việc đăng nhập, bạn đồng ý với Điều khoản và Chính sách của SoulMate',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Logo Trái tim tình yêu phong cách Tinder
  Widget _buildTinderLogo() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.favorite_rounded,
          color: Color(0xFFFD297B),
          size: 42,
        ),
      ),
    );
  }

  /// Bộ chuyển đổi Đăng nhập / Đăng ký thanh lịch
  Widget _buildTinderTabSwitcher() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isRegister = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !_isRegister ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: !_isRegister
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Đăng nhập',
                  style: TextStyle(
                    color: !_isRegister ? const Color(0xFFFD297B) : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isRegister = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isRegister ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: _isRegister
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Đăng ký',
                  style: TextStyle(
                    color: _isRegister ? const Color(0xFFFD297B) : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Input Field phong cách Tinder: Nền trắng tinh khôi, chữ đen than sắc nét, icon hồng nổi bật
  Widget _buildTinderInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? suffixIcon,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: const TextStyle(
          color: Color(0xFF1E1E1E),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: const Color(0xFFFD297B),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFFFD297B), size: 22),
          prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 22),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Nút bấm chính dạng Viên thuốc màu trắng (Signature Tinder Style)
  Widget _buildTinderButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _submit,
          borderRadius: BorderRadius.circular(30),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Color(0xFFFD297B),
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    _isRegister ? 'TẠO TÀI KHOẢN' : 'ĐĂNG NHẬP',
                    style: const TextStyle(
                      color: Color(0xFFFD297B),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Nút mạng xã hội bo tròn viên thuốc viền mỏng
  Widget _buildSocialPill({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }


  /// Badge cấu hình máy chủ
  Widget _buildServerBadge() {
    return InkWell(
      onTap: () => showServerHostDialog(context, ref),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Máy chủ: ${AppConfig.serverHost}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              color: Colors.white.withValues(alpha: 0.6),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}
