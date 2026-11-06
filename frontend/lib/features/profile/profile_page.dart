// profile_page.dart — Trang cá nhân của chính mình (kiểu Facebook).
//
// Vai trò: ảnh bìa + avatar, thống kê bài viết/bạn bè/Xu/Kim cương, danh sách
// bạn bè thật, ngày tham gia thật, bài viết của mình (tải riêng theo userId),
// menu ⋯ (đổi mật khẩu, ví, VIP, chẩn đoán mạng) và nút Đăng xuất.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/data/repositories/social_repository.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/feed/create_post_page.dart';
import 'package:dating_app/features/feed/feed_page.dart' show CommentsSheet;
import 'package:dating_app/features/profile/edit_profile_page.dart';
import 'package:dating_app/features/profile/network_demo_page.dart';
import 'package:dating_app/features/profile/wallet_page.dart';
import 'package:dating_app/features/profile/vip_page.dart';
import 'package:dating_app/features/chat/chat_detail_page.dart';
import 'package:dating_app/features/chat/friends_page.dart';
import 'package:dating_app/features/chat/search_users_page.dart';

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

/// Tải bạn bè/bài viết của tôi và xử lý các thao tác trên trang.
class _ProfilePageState extends ConsumerState<ProfilePage> {
  // Tải bạn bè và bài viết của tôi khi mở trang.
  @override
  void initState() {
    super.initState();
    // Tải đầy đủ bài viết của chính mình từ database (không phụ thuộc phần đã
    // tải trong bảng tin chung). Realtime sẽ cập nhật tiếp qua `feedRealtimeProvider`.
    Future.microtask(() {
      if (!mounted) return;
      final me = ref.read(currentUserProvider);
      ref.read(myPostsProvider.notifier).load(me.id);
      ref.read(friendsProvider.notifier).load();
    });
  }

  // Đổi giá trị giới tính sang tiếng Việt.
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

  // Dựng toàn bộ trang: bìa, avatar, thống kê, bạn bè, bài viết.
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    // Bài viết của mình: tải riêng theo tác giả + cập nhật realtime.
    final myPosts = ref.watch(myPostsProvider);
    // Bạn bè đọc từ database (bảng friendships), cập nhật realtime.
    final friends = ref.watch(friendsProvider);

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
            tooltip: 'Tìm bạn bè',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchUsersPage()),
            ),
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
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
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
                        const SizedBox(height: 12),

                        // Thống kê cá nhân — tất cả đều tính từ dữ liệu thật.
                        Row(
                          children: [
                            _FbStat(label: 'Bài viết', value: '${myPosts.length}'),
                            _FbStat(label: 'Bạn bè', value: '${friends.length}'),
                            _FbStat(label: 'Xu', value: '${user.coins}'),
                            _FbStat(label: 'Kim cương', value: '${user.diamonds}'),
                          ],
                        ),
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
                    boldText: _joinDateText(user.createdAt),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bạn bè', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text('${friends.length} người bạn', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                      TextButton(
                        onPressed: () => _openFriends(context),
                        child: const Text('Xem tất cả', style: TextStyle(color: Color(0xFF1877F2))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bạn bè thật từ database (tối đa 6 người mới nhất).
                  if (friends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Chưa có bạn bè — hãy chơi Trò chơi tâm giao để kết bạn',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    )
                  else
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                      children: friends
                          .take(6)
                          .map((f) => _FbFriendCard(
                                name: f.user.name,
                                emoji: f.user.avatar,
                                online: f.user.isOnline,
                                onTap: () => _openChatWith(f),
                              ))
                          .toList(),
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
                      onPressed: () => _openFriends(context),
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
                      _FbPostActionBtn(
                        icon: Icons.edit_note,
                        color: const Color(0xFF1877F2),
                        label: 'Trạng thái',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CreatePostPage()),
                          );
                        },
                      ),
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

            const SizedBox(height: 10),

            // ================= 6. ĐĂNG XUẤT =================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context, ref),
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Đăng xuất',
                    style: TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// "Tham gia từ" — lấy ngày tạo tài khoản thật trên server.
  String _joinDateText(DateTime? createdAt) {
    final d = createdAt?.toLocal();
    if (d == null) return 'chưa xác định';
    return 'ngày ${d.day}/${d.month}/${d.year}';
  }

  // Mở danh sách bạn bè.
  void _openFriends(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FriendsPage()),
    );
  }

  // Mở chat với một người bạn.
  void _openChatWith(FriendEntry f) {
    final conversationId = f.conversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          conversationId: conversationId,
          partnerId: f.user.id,
          partnerName: f.user.name,
          partnerAvatar: f.user.avatar,
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

  // Xác nhận rồi đăng xuất và xoá dữ liệu đã cache.
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

  // Một dòng thông tin chi tiết kèm icon.
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

// Thẻ một người bạn trong lưới bạn bè.
class _FbFriendCard extends StatelessWidget {
  const _FbFriendCard({
    required this.name,
    required this.emoji,
    this.online = false,
    this.onTap,
  });
  final String name;
  final String emoji;
  final bool online;
  final VoidCallback? onTap;

  // Nút Thích/Bình luận/Chia sẻ dưới bài viết của trang cá nhân.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: _AvatarContent(avatar: emoji),
                  ),
                ),
                if (online)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
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
      ),
    );
  }
}

/// Avatar của bạn bè: URL thì hiển thị ảnh, còn lại hiển thị emoji như dữ liệu cũ.
class _AvatarContent extends StatelessWidget {
  const _AvatarContent({required this.avatar});
  final String avatar;

  // Thẻ bạn bè trong lưới: avatar, tên và nút nhắn tin.
  @override
  Widget build(BuildContext context) {
    if (avatar.startsWith('/uploads/') || avatar.startsWith('http')) {
      return AppAvatar(avatar: avatar, size: 88);
    }
    return Text(avatar, style: const TextStyle(fontSize: 36));
  }
}

/// Một ô thống kê nhỏ trên trang cá nhân (bài viết / bạn bè / xu…).
class _FbStat extends StatelessWidget {
  const _FbStat({required this.label, required this.value});
  final String label;
  final String value;

  // Nút Thích đổi màu và icon khi bài đã được thích.
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// Nút Thích/Bình luận/Chia sẻ dưới bài viết.
class _FbPostActionBtn extends StatelessWidget {
  const _FbPostActionBtn({required this.icon, required this.color, required this.label, this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  // Chọn cách hiển thị avatar: ảnh tải lên hay emoji.
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

// Dấu chia dọc giữa các nút hành động.
class _FbVerticalDivider extends StatelessWidget {
  const _FbVerticalDivider();
  // Vạch chia dọc giữa các nút hành động.
  @override
  Widget build(BuildContext context) {
    return Container(height: 18, width: 1, color: const Color(0xFFCED0D4));
  }
}

// Thẻ bài viết trong trang cá nhân.
class _FbPostCard extends ConsumerWidget {
  const _FbPostCard({required this.post});
  final PostModel post;

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CommentsSheet(postId: post.id),
    );
  }

  /// Chia sẻ qua hệ điều hành, chỉ ghi nhận lượt khi bảng chia sẻ báo thành công.
  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final url = '${AppConfig.apiBaseUrl}/feed/${post.id}';
    final text = [
      if ((post.content ?? '').trim().isNotEmpty) post.content!.trim(),
      'Bài viết của ${post.userName} trên SoulMate: $url',
    ].join('\n\n');
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, title: 'Chia sẻ bài viết'),
      );
      if (!context.mounted || result.status != ShareResultStatus.success) {
        return;
      }
      final error = await ref
          .read(feedProvider.notifier)
          .sharePost(post.id, confirmed: true);
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được bảng chia sẻ')),
        );
      }
    }
  }

  // Thời gian tương đối của bài viết.
  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    return '${t.day} thg ${t.month}';
  }

  // Dựng thẻ bài viết và các thao tác.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              _FbReactBtn(
                icon: post.likedByMe
                    ? Icons.thumb_up_alt
                    : Icons.thumb_up_alt_outlined,
                label: 'Thích',
                active: post.likedByMe,
                onTap: () => ref.read(feedProvider.notifier).toggleLike(post.id),
              ),
              _FbReactBtn(
                icon: Icons.chat_bubble_outline,
                label: 'Bình luận',
                onTap: () => _openComments(context),
              ),
              _FbReactBtn(
                icon: Icons.share_outlined,
                label: 'Chia sẻ',
                onTap: () => _share(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Nút thích có đổi màu/icon theo trạng thái.
class _FbReactBtn extends StatelessWidget {
  const _FbReactBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  // Một ô thống kê: con số ở trên, nhãn ở dưới.
  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF1877F2) : const Color(0xFF65676B);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
