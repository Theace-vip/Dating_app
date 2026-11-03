import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/feed/create_post_page.dart';
import 'package:dating_app/features/profile/edit_profile_page.dart';
import 'package:dating_app/features/profile/network_demo_page.dart';
import 'package:dating_app/features/profile/wallet_page.dart';
import 'package:dating_app/features/profile/vip_page.dart';

/// Trang Cá nhân (User Profile) thiết kế CHUẨN 100% PHONG CÁCH FACEBOOK:
/// - Ảnh bìa (Cover Photo) lớn, góc phải có nút Camera tròn đổi ảnh bìa
/// - Ảnh đại diện (Profile Picture) lớn đè lên ảnh bìa, viền trắng 4px, nút máy ảnh nhỏ
/// - Tên người dùng in đậm, tích xanh VIP, Tiểu sử (Bio)
/// - Hàng nút tác vụ Facebook: [+ Thêm vào tin], [Chỉnh sửa trang cá nhân], [...]
/// - Khối "Chi tiết" (Facebook Details): Email đăng ký, SĐT, Tuổi, Giới tính, Quê quán, Ngày tham gia, Sở thích
/// - Nút "Chỉnh sửa chi tiết công khai"
/// - Khối "Bạn bè" (Friends): Lưới avatar bạn bè
/// - Khung đăng trạng thái "Bạn đang nghĩ gì?" kèm nút Ảnh/Video
/// - Nhật ký bài viết Facebook với nút Like 👍, Bình luận 💬, Chia sẻ ↗️
/// - Menu cài đặt 3 chấm [...] chuẩn Facebook: VIP, Ví & Xu, Đổi mật khẩu, Trạng thái mạng, Đăng xuất
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String _genderText(Gender g) {
    switch (g) {
      case Gender.male:
        return 'Nam';
      case Gender.female:
        return 'Nữ';
      case Gender.other:
        return 'Khác';
    }
  }

  IconData _genderIcon(Gender g) {
    switch (g) {
      case Gender.male:
        return Icons.male;
      case Gender.female:
        return Icons.female;
      case Gender.other:
        return Icons.transgender;
    }
  }

  /// Đổi mật khẩu
  Future<void> _showChangePassword(BuildContext context, WidgetRef ref) async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi mật khẩu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Mật khẩu hiện tại'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Mật khẩu mới (8+ ký tự)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Nhập lại mật khẩu mới'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lưu thay đổi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ mật khẩu')),
      );
      return;
    }
    if (newCtrl.text != confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu nhập lại không khớp')),
      );
      return;
    }
    final err = await ref
        .read(authProvider.notifier)
        .changePassword(oldCtrl.text, newCtrl.text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      err == null
          ? const SnackBar(content: Text('Đã đổi mật khẩu thành công!'), backgroundColor: AppColors.success)
          : SnackBar(content: Text(err), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final allPosts = ref.watch(feedProvider);
    final myPosts = allPosts.where((p) => p.userId == user.id).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Màu nền Facebook chuẩn
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          user.name,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            tooltip: 'Tìm kiếm',
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ================= 1. COVER PHOTO & AVATAR (FACEBOOK STYLE) =================
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Ảnh bìa Facebook
                      Container(
                        height: 190,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3B5998), Color(0xFF8B9DC3), Color(0xFFDFE3EE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.25,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF1877F2), Color(0xFF8A3AB9)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Nút Camera đổi ảnh bìa góc phải dưới
                            Positioned(
                              right: 14,
                              bottom: 14,
                              child: InkWell(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tính năng đổi ảnh bìa đang kết nối')),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE4E6EB),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 18, color: Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Avatar lớn đè lên ảnh bìa (Facebook Profile Picture)
                      Positioned(
                        left: 16,
                        bottom: -45,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: AppAvatar(
                                avatar: user.avatar,
                                size: 110,
                                vipFrame: user.isVip ? '👑' : null,
                                isOnline: true,
                              ),
                            ),
                            // Nút máy ảnh đổi Avatar góc nhỏ
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE4E6EB),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, size: 16, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 52),

                  // Tên người dùng & Bio
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (user.isVip) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Color(0xFF1877F2), size: 20),
                            ],
                          ],
                        ),
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.bio!,
                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Hàng nút Facebook Actions: [+ Thêm vào tin] [Chỉnh sửa trang cá nhân] [...]
                        Row(
                          children: [
                            // Nút Xanh [+ Thêm vào tin]
                            Expanded(
                              flex: 5,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1877F2), // Màu xanh Facebook
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const CreatePostPage()),
                                  );
                                },
                                icon: const Icon(Icons.add_circle, color: Colors.white, size: 18),
                                label: const Text(
                                  'Thêm vào tin',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Nút Xám [Chỉnh sửa trang cá nhân]
                            Expanded(
                              flex: 5,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE4E6EB),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                                  );
                                },
                                icon: const Icon(Icons.edit, color: Colors.black87, size: 16),
                                label: const Text(
                                  'Chỉnh sửa',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Nút 3 chấm [...] mở menu cài đặt Facebook
                            InkWell(
                              onTap: () => _showFacebookMenuSheet(context, ref, user),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE4E6EB),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.more_horiz, color: Colors.black87, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  const Divider(height: 1, thickness: 1, color: Color(0xFFCED0D4)),

                  // Thanh Tab Facebook: [Bài viết] | [Ảnh] | [Ví & Xu]
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFF1877F2), width: 3)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Bài viết',
                            style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletPage()));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🪙 Ví & Xu', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFE4E6EB), borderRadius: BorderRadius.circular(10)),
                                  child: Text('${user.coins}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipPage()));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            child: const Text(
                              '👑 VIP',
                              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ================= 2. KHỐI CHI TIẾT (FACEBOOK DETAILS) =================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chi tiết',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  _FbDetailItem(
                    icon: Icons.email,
                    text: 'Email đăng ký tài khoản: ',
                    boldText: user.email ?? 'Chưa cập nhật',
                  ),
                  _FbDetailItem(
                    icon: Icons.phone,
                    text: 'Số điện thoại: ',
                    boldText: user.phone != null && user.phone!.isNotEmpty ? user.phone! : 'Chưa liên kết',
                  ),
                  _FbDetailItem(
                    icon: Icons.cake,
                    text: 'Độ tuổi: ',
                    boldText: '${user.age} tuổi',
                  ),
                  _FbDetailItem(
                    icon: _genderIcon(user.gender),
                    text: 'Giới tính: ',
                    boldText: _genderText(user.gender),
                  ),
                  _FbDetailItem(
                    icon: Icons.verified_user,
                    text: 'Trạng thái tài khoản: ',
                    boldText: user.profileCompleted ? 'Đã hoàn tất hồ sơ ✓' : 'Chưa hoàn tất',
                    boldColor: user.profileCompleted ? AppColors.success : AppColors.warning,
                  ),
                  _FbDetailItem(
                    icon: Icons.access_time_filled,
                    text: 'Tham gia SoulMate từ ',
                    boldText: 'Tháng 10 năm 2026',
                  ),

                  // Thẻ sở thích
                  if (user.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F2F5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text('🏷️ $t', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Nút Xám rộng: [Chỉnh sửa chi tiết công khai]
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE4E6EB),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EditProfilePage()),
                        );
                      },
                      child: const Text(
                        'Chỉnh sửa chi tiết công khai',
                        style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ================= 3. KHỐI BẠN BÈ (FACEBOOK FRIENDS) =================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bạn bè', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text('128 người bạn', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Tìm bạn bè', style: TextStyle(color: Color(0xFF1877F2))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Lưới 6 avatar bạn bè demo Facebook
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                    children: [
                      _FbFriendCard(name: 'Minh Tuấn', emoji: '🐻'),
                      _FbFriendCard(name: 'Phương Linh', emoji: '🌸'),
                      _FbFriendCard(name: 'Hải Đăng', emoji: '🎸'),
                      _FbFriendCard(name: 'Thu Trang', emoji: '🎨'),
                      _FbFriendCard(name: 'Đức Anh', emoji: '⚽'),
                      _FbFriendCard(name: 'Khánh Vy', emoji: '🧋'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE4E6EB),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {},
                      child: const Text(
                        'Xem tất cả bạn bè',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ================= 4. KHUNG ĐĂNG BÀI FACEBOOK (WHAT'S ON YOUR MIND?) =================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      AppAvatar(avatar: user.avatar, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CreatePostPage()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFFCED0D4), width: 0.5),
                            ),
                            child: const Text(
                              'Bạn đang nghĩ gì?',
                              style: TextStyle(color: Color(0xFF65676B), fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFFCED0D4)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _FbPostActionBtn(icon: Icons.videocam, color: Colors.red, label: 'Phát trực tiếp'),
                      const _FbVerticalDivider(),
                      _FbPostActionBtn(
                        icon: Icons.photo_library,
                        color: Colors.green,
                        label: 'Ảnh',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CreatePostPage()),
                          );
                        },
                      ),
                      const _FbVerticalDivider(),
                      _FbPostActionBtn(icon: Icons.location_on, color: Colors.pink, label: 'Check in'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ================= 5. BÀI VIẾT CỦA BẠN (FACEBOOK POSTS FEED) =================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              alignment: Alignment.centerLeft,
              child: const Text(
                'Bài viết của bạn',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),

            if (myPosts.isEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                child: const Column(
                  children: [
                    Icon(Icons.feed_outlined, size: 48, color: Color(0xFFCED0D4)),
                    SizedBox(height: 8),
                    Text('Chưa có bài viết nào', style: TextStyle(color: Color(0xFF65676B), fontSize: 15)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: myPosts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _FbPostCard(post: myPosts[i]),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Menu 3 chấm [...] chuẩn Facebook
  void _showFacebookMenuSheet(BuildContext context, WidgetRef ref, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.workspace_premium, color: Color(0xFFFFB020)),
                title: const Text('Gói thành viên VIP', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Xem huy hiệu và ưu đãi đặc quyền'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF1877F2)),
                title: const Text('Ví & Xu thưởng', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Số dư: ${user.coins} Xu • ${user.diamonds} Kim cương'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset, color: Color(0xFF42B72A)),
                title: const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChangePassword(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.wifi, color: Colors.blueGrey),
                title: const Text('Kiểm tra máy chủ & Mạng', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NetworkDemoPage()));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Đăng xuất tài khoản', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmLogout(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ================= CÁC WIDGET PHỤ TRỢ FACEBOOK =================

class _FbDetailItem extends StatelessWidget {
  const _FbDetailItem({
    required this.icon,
    required this.text,
    required this.boldText,
    this.boldColor,
  });

  final IconData icon;
  final String text;
  final String boldText;
  final Color? boldColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF65676B)),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Color(0xFF050505)),
                children: [
                  TextSpan(text: text),
                  TextSpan(
                    text: boldText,
                    style: TextStyle(fontWeight: FontWeight.bold, color: boldColor ?? Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FbFriendCard extends StatelessWidget {
  const _FbFriendCard({required this.name, required this.emoji});
  final String name;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 36)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _FbPostActionBtn extends StatelessWidget {
  const _FbPostActionBtn({required this.icon, required this.color, required this.label, this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF65676B))),
        ],
      ),
    );
  }
}

class _FbVerticalDivider extends StatelessWidget {
  const _FbVerticalDivider();
  @override
  Widget build(BuildContext context) {
    return Container(height: 18, width: 1, color: const Color(0xFFCED0D4));
  }
}

class _FbPostCard extends StatelessWidget {
  const _FbPostCard({required this.post});
  final PostModel post;

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    return '${diff.day} thg ${diff.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bài post Facebook
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                AppAvatar(avatar: post.userAvatar, size: 40),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Row(
                      children: [
                        Text(_timeAgo(post.createdAt), style: const TextStyle(color: Color(0xFF65676B), fontSize: 12)),
                        const SizedBox(width: 4),
                        const Text('•', style: TextStyle(color: Color(0xFF65676B), fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.public, size: 12, color: Color(0xFF65676B)),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.more_horiz, color: Color(0xFF65676B)),
              ],
            ),
          ),

          // Nội dung text
          if (post.content != null && post.content!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(post.content!, style: const TextStyle(fontSize: 15, height: 1.35, color: Color(0xFF050505))),
            ),
          ],

          // Ảnh đính kèm full width Facebook
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: 10),
            isNetworkAvatar(post.media.first)
                ? Image.network(
                    AppConfig.absoluteUrl(post.media.first),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    color: const Color(0xFFF0F2F5),
                    alignment: Alignment.center,
                    child: Text(post.media.first, style: const TextStyle(fontSize: 60)),
                  ),
          ],

          // Số lượt Like & Bình luận Facebook
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xFF1877F2), shape: BoxShape.circle),
                      child: const Icon(Icons.thumb_up, size: 11, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text('${post.likes}', style: const TextStyle(color: Color(0xFF65676B), fontSize: 13)),
                  ],
                ),
                Text('${post.comments} bình luận', style: const TextStyle(color: Color(0xFF65676B), fontSize: 13)),
              ],
            ),
          ),

          const Divider(height: 8, color: Color(0xFFCED0D4)),

          // 3 Nút Tương tác Facebook: [Thích] [Bình luận] [Chia sẻ]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _FbReactBtn(icon: Icons.thumb_up_alt_outlined, label: 'Thích'),
              _FbReactBtn(icon: Icons.chat_bubble_outline, label: 'Bình luận'),
              _FbReactBtn(icon: Icons.share_outlined, label: 'Chia sẻ'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FbReactBtn extends StatelessWidget {
  const _FbReactBtn({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF65676B)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Color(0xFF65676B), fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
