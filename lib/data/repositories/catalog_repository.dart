import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/data/api/api_client.dart';

/// Một lựa chọn quà do backend định giá; client chỉ hiển thị và gửi id.
class RoomGiftOption {
  const RoomGiftOption({
    required this.id,
    required this.emoji,
    required this.cost,
  });

  final String id;
  final String emoji;
  final int cost;

  factory RoomGiftOption.fromJson(Map<String, dynamic> json) => RoomGiftOption(
        id: json['id'] as String,
        emoji: json['emoji'] as String,
        cost: (json['cost'] as num).toInt(),
      );
}

/// Gói Xu chỉ để hiển thị; mua chỉ bật sau khi server có xác minh thanh toán.
class CoinPackageOption {
  const CoinPackageOption({
    required this.id,
    required this.coins,
    required this.priceVnd,
    required this.priceLabel,
  });

  final String id;
  final int coins;
  final int priceVnd;
  final String priceLabel;

  factory CoinPackageOption.fromJson(Map<String, dynamic> json) =>
      CoinPackageOption(
        id: json['id'] as String,
        coins: (json['coins'] as num).toInt(),
        priceVnd: (json['priceVnd'] as num).toInt(),
        priceLabel: json['priceLabel'] as String,
      );
}

/// Một quyền lợi VIP được cấu hình ở server.
class VipBenefitOption {
  const VipBenefitOption({required this.emoji, required this.title});

  final String emoji;
  final String title;

  factory VipBenefitOption.fromJson(Map<String, dynamic> json) =>
      VipBenefitOption(
        emoji: json['emoji'] as String,
        title: json['title'] as String,
      );
}

/// Model catalog tổng hợp; dữ liệu nghiệp vụ tĩnh được tải từ API thay vì hard-code.
class AppCatalog {
  const AppCatalog({
    required this.avatars,
    required this.interests,
    required this.roomGifts,
    required this.coinPackages,
    required this.coinPurchasesEnabled,
    required this.vipPlanTitle,
    required this.vipPriceLabel,
    required this.vipBenefits,
    required this.vipPurchasesEnabled,
    required this.textSeconds,
    required this.voiceSeconds,
    required this.heartUnlockAfterSeconds,
    required this.callRingingTimeoutSeconds,
  });

  final List<String> avatars;
  final List<String> interests;
  final List<RoomGiftOption> roomGifts;
  final List<CoinPackageOption> coinPackages;
  final bool coinPurchasesEnabled;
  final String vipPlanTitle;
  final String vipPriceLabel;
  final List<VipBenefitOption> vipBenefits;
  final bool vipPurchasesEnabled;
  final int textSeconds;
  final int voiceSeconds;
  final int heartUnlockAfterSeconds;
  final int callRingingTimeoutSeconds;

  factory AppCatalog.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> objects(dynamic value) => (value as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);

    final profile = Map<String, dynamic>.from(json['profile'] as Map);
    final rooms = Map<String, dynamic>.from(json['rooms'] as Map);
    final wallet = Map<String, dynamic>.from(json['wallet'] as Map);
    final vip = Map<String, dynamic>.from(json['vip'] as Map);
    final matching = Map<String, dynamic>.from(json['matching'] as Map);
    final call = Map<String, dynamic>.from(json['call'] as Map);
    final plan = Map<String, dynamic>.from(vip['plan'] as Map);

    return AppCatalog(
      avatars: (profile['avatars'] as List).cast<String>(),
      interests: (profile['interests'] as List).cast<String>(),
      roomGifts: objects(rooms['gifts'])
          .map(RoomGiftOption.fromJson)
          .toList(growable: false),
      coinPackages: objects(wallet['coinPackages'])
          .map(CoinPackageOption.fromJson)
          .toList(growable: false),
      coinPurchasesEnabled: wallet['purchasesEnabled'] == true,
      vipPlanTitle: plan['title'] as String,
      vipPriceLabel: plan['priceLabel'] as String,
      vipBenefits: objects(plan['benefits'])
          .map(VipBenefitOption.fromJson)
          .toList(growable: false),
      vipPurchasesEnabled: vip['purchasesEnabled'] == true,
      textSeconds: (matching['textSeconds'] as num).toInt(),
      voiceSeconds: (matching['voiceSeconds'] as num).toInt(),
      heartUnlockAfterSeconds:
          (matching['heartUnlockAfterSeconds'] as num).toInt(),
      callRingingTimeoutSeconds:
          (call['ringingTimeoutSeconds'] as num).toInt(),
    );
  }
}

/// Tải catalog một lần qua API; màn hình dùng chung dữ liệu và trạng thái tải/lỗi.
final appCatalogProvider = FutureProvider<AppCatalog>((ref) async {
  final response = await ref.read(apiClientProvider).get('/api/catalog');
  return AppCatalog.fromJson(Map<String, dynamic>.from(response as Map));
});
