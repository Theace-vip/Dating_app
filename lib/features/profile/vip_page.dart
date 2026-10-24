import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/data/repositories/catalog_repository.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';

class VipPage extends ConsumerWidget {
  const VipPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final catalog = ref.watch(appCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Đặc quyền VIP')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: const [
                  Text('👑', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 8),
                  Text('SoulMate VIP',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Mở khóa mọi đặc quyền tìm kiếm tình yêu',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...catalog.when(
              loading: () => const [
                ListTile(title: Text('Đang tải quyền lợi VIP...')),
              ],
              error: (_, _) => const [
                ListTile(title: Text('Không tải được quyền lợi VIP')),
              ],
              data: (value) => value.vipBenefits.map((benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(benefit.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 14),
                        Text(benefit.title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                )).toList(growable: false),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Column(
                children: [
                  catalog.when(
                    loading: () => const Text('Đang tải gói VIP...'),
                    error: (_, _) => const Text('Không tải được gói VIP'),
                    data: (value) => Column(
                      children: [
                        Text(
                          value.vipPlanTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value.vipPriceLabel,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (user.isVip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Bạn đang là VIP',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600)),
                    )
                  else
                    AppButton(
                      label: catalog.valueOrNull?.vipPurchasesEnabled == true
                          ? 'Đăng ký'
                          : 'Sắp có',
                      // Server giữ nút mua tắt cho tới khi bật xác minh thanh toán.
                      onPressed: null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
