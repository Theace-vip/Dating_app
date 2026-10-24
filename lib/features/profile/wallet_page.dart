import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/data/repositories/catalog_repository.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final catalog = ref.watch(appCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ví của tôi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _BalanceCard(
                        emoji: '🪙', label: 'Xu', value: '${user.coins}')),
                const SizedBox(width: 12),
                Expanded(
                    child: _BalanceCard(
                        emoji: '💎',
                        label: 'Kim cương',
                        value: '${user.diamonds}')),
              ],
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nạp xu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ...catalog.when(
              loading: () => const [
                Card(child: ListTile(title: Text('Đang tải gói Xu...'))),
              ],
              error: (_, _) => const [
                Card(child: ListTile(title: Text('Không tải được bảng giá'))),
              ],
              data: (value) => value.coinPackages
                  .map((package) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: const Text('🪙', style: TextStyle(fontSize: 32)),
                          title: Text(
                            '${package.coins} Xu',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(package.priceLabel),
                          trailing: TextButton(
                            // Không mở thanh toán giả; chờ tích hợp provider + xác minh receipt.
                            onPressed: value.coinPurchasesEnabled
                                ? () => ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Thanh toán sẽ được xử lý an toàn qua máy chủ'),
                                      ),
                                    )
                                : null,
                            child: Text(
                              value.coinPurchasesEnabled ? 'Nạp' : 'Sắp có',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(
      {required this.emoji, required this.label, required this.value});
  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}
