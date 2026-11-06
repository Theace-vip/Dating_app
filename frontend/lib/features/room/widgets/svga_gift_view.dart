// svga_gift_view.dart — Phát hoạt cảnh quà (SVGA).
//
// Vai trò: nạp file .svga trong assets, chạy animation toàn màn hình với tốc
// độ và số vòng do trang gọi truyền vào, báo khi phát xong để dọn overlay.

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:svgaplayer/svgaplayer_flutter.dart';

/// Placeholder Lottie hiển thị trong lúc giải mã SVGA, và giữ nguyên nếu file
/// SVGA lỗi (ví dụ file SVGA 1.0 không đọc được) để ô quà không bị trống.
const String kGiftPlaceholderLottie = 'assets/lottie/gift_sparkle.json';

/// Phát một file .svga trong assets bằng CustomPainter của SVGAPlayer.
///
/// - [loop] = true: dùng cho lưới chọn quà (chạy lặp để xem trước).
/// - [loop] = false: chạy [plays] lần rồi gọi [onCompleted] (hiệu ứng quà).
/// - [speed] < 1 làm chậm animation (0.7 = chậm hơn 30%).
///
/// Nếu asset không giải mã được, widget chỉ để trống và ghi log thay vì làm
/// sập màn hình phòng.
class SvgaGiftView extends StatefulWidget {
  const SvgaGiftView({
    super.key,
    required this.asset,
    this.size = 180,
    this.loop = false,
    this.plays = 1,
    this.speed = 1.0,
    this.onCompleted,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double size;
  final bool loop;

  /// Số lần phát khi [loop] = false (>= 1).
  final int plays;

  /// Hệ số tốc độ: 1.0 là gốc, 0.5 là chậm gấp đôi.
  final double speed;
  final VoidCallback? onCompleted;
  final BoxFit fit;

  @override
  State<SvgaGiftView> createState() => _SvgaGiftViewState();
}

/// Nạp animation, phát đúng số vòng và báo khi phát xong.
class _SvgaGiftViewState extends State<SvgaGiftView>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _controller =
      SVGAAnimationController(vsync: this);
  bool _ready = false;
  int _finishedPlays = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Nạp file animation từ assets.
  Future<void> _load() async {
    try {
      final videoItem =
          await SVGAParser.shared.decodeFromAssets(widget.asset);
      if (!mounted) return;
      _controller.videoItem = videoItem;
      // videoItem đặt duration theo frames/fps; kéo dài duration để chạy chậm.
      final speed = widget.speed.clamp(0.1, 4.0);
      final base = _controller.duration;
      if (speed != 1.0 && base != null && base > Duration.zero) {
        _controller.duration = base * (1 / speed);
      }
      _controller.addStatusListener(_handleStatus);
      if (widget.loop) {
        _controller.repeat();
      } else {
        // ignore: unawaited_futures
        _controller.forward();
      }
      setState(() => _ready = true);
    } catch (error) {
      debugPrint('Không giải mã được SVGA ${widget.asset}: $error');
      // Giữ Lottie thay thế trong chốc lát rồi báo xong, để banner quà không
      // kẹt lại vĩnh viễn khi file SVGA lỗi.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) widget.onCompleted?.call();
      });
    }
  }

  // Bắt sự kiện phát xong để báo ngược lên trang.
  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || widget.loop || !mounted) return;
    _finishedPlays++;
    if (_finishedPlays < widget.plays) {
      // Phát lại từ đầu cho tới khi đủ số lần yêu cầu.
      // ignore: unawaited_futures
      _controller.forward(from: 0);
      return;
    }
    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  // Khung hiển thị animation, co giãn theo màn hình.
  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.asset(
          kGiftPlaceholderLottie,
          repeat: true,
          fit: BoxFit.contain,
        ),
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: SVGAImage(
        _controller,
        fit: widget.fit,
        clearsAfterStop: false,
      ),
    );
  }
}
