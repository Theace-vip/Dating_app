import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dating_app/core/constants/app_config.dart';

enum RtcState { connecting, connected, failed, closed }

/// Phiên WebRTC tái sử dụng cho: gọi thoại/video 1-1, Voice Game, mic phòng.
/// - [isInitiator]: bên nào tạo Offer (server đã định nghĩa trước).
/// - [send]: hàm gửi tín hiệu signaling (đã gắn đúng room/callId của feature).
class RtcSession {
  RtcSession({
    required this.isVideo,
    required this.isInitiator,
    required this.send,
  });

  final bool isVideo;
  final bool isInitiator;
  final void Function(Map<String, dynamic> data) send;

  RTCPeerConnection? _pc;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final List<RTCIceCandidate> _pendingCandidates = [];
  // Tín hiệu signaling đến TRƯỚC khi start() tạo xong PeerConnection
  // (ví dụ offer đến trong lúc app đang xin quyền micro) -> xếp hàng, xử lý khi sẵn sàng.
  // Trước đây bị drop -> cuộc gọi treo "Đang kết nối..." mãi không nối.
  final List<Map<String, dynamic>> _queuedSignals = [];
  bool _readyForSignals = false;
  Future<void> _signalQueue = Future<void>.value();
  bool _remoteDescriptionSet = false;
  bool _disposed = false;

  final _stateCtrl = StreamController<RtcState>.broadcast();
  final _remoteCtrl = StreamController<MediaStream>.broadcast();

  Stream<RtcState> get state => _stateCtrl.stream;
  Stream<MediaStream> get onRemoteStream => _remoteCtrl.stream;
  RtcState currentState = RtcState.connecting;

  void _emit(RtcState s) {
    currentState = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  /// ===== Vòng đời kết nối =====
  /// Xin quyền lấy media cục bộ, thêm track vào peer connection và cài callback WebRTC.
  /// Chỉ sau khi có track mới bật cờ nhận signaling để tránh tạo answer thiếu media.
  Future<void> start() async {
    _pc = await createPeerConnection({'iceServers': AppConfig.iceServers});

    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo,
    });
    for (final track in localStream!.getTracks()) {
      await _pc!.addTrack(track, localStream!);
    }

    _pc!.onIceCandidate = (candidate) {
      if (_disposed) return;
      send({
        'kind': 'ice',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _pc!.onTrack = (event) {
      final stream = event.streams.isNotEmpty ? event.streams.first : null;
      if (stream != null && !_disposed) {
        remoteStream = stream;
        if (!_remoteCtrl.isClosed) _remoteCtrl.add(stream);
      }
    };

    _pc!.onConnectionState = (state) {
      if (_disposed) return;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _emit(RtcState.connected);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _emit(RtcState.failed);
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _emit(RtcState.closed);
        default:
          break;
      }
    };

    _readyForSignals = true;
    _emit(RtcState.connecting);

    // Xử lý các tín hiệu đến sớm (offer/answer/ice đến khi peer connection
    // và các track micro/camera đã sẵn sàng).
    final queued = List.of(_queuedSignals);
    _queuedSignals.clear();
    for (final data in queued) {
      if (_disposed) return;
      await _processSignal(data);
    }

    if (isInitiator) await _makeOffer();
  }

  /// Bên gọi khởi tạo SDP offer sau khi audio/video track đã sẵn sàng.
  Future<void> _makeOffer() async {
    final pc = _pc;
    if (pc == null) return;
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    send({'kind': 'offer', 'sdp': offer.sdp});
  }

  /// ===== Xử lý signaling =====
  /// Nhận tín hiệu signaling từ đối phương (offer/answer/ice).
  /// Tín hiệu được xếp hàng và áp tuần tự; ICE đến trước SDP được giữ lại
  /// cho tới khi setRemoteDescription xong.
  Future<void> handleSignal(Map<String, dynamic> data) async {
    if (_disposed) return;
    if (!_readyForSignals) {
      // Chưa xin xong quyền/tạo track -> giữ signaling thay vì tạo answer thiếu media.
      if (_queuedSignals.length < 100) _queuedSignals.add(data);
      return;
    }
    // Áp SDP/ICE tuần tự để tránh setRemoteDescription và addCandidate chạy đè nhau.
    final next = _signalQueue.then((_) => _processSignal(data));
    _signalQueue = next.catchError((Object _) {});
    await next;
  }

  /// Áp SDP offer/answer hoặc ICE candidate lên RTCPeerConnection hiện tại.
  Future<void> _processSignal(Map<String, dynamic> data) async {
    final pc = _pc;
    if (pc == null || _disposed) return;
    try {
      switch (data['kind']) {
        case 'offer':
          await pc.setRemoteDescription(
            RTCSessionDescription(data['sdp'] as String?, 'offer'),
          );
          _remoteDescriptionSet = true;
          await _flushPendingCandidates();
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          send({'kind': 'answer', 'sdp': answer.sdp});
        case 'answer':
          await pc.setRemoteDescription(
            RTCSessionDescription(data['sdp'] as String?, 'answer'),
          );
          _remoteDescriptionSet = true;
          await _flushPendingCandidates();
        case 'ice':
          final c = RTCIceCandidate(
            data['candidate'] as String?,
            data['sdpMid'] as String?,
            (data['sdpMLineIndex'] as num?)?.toInt(),
          );
          if (_remoteDescriptionSet) {
            await pc.addCandidate(c);
          } else {
            _pendingCandidates.add(c);
          }
        default:
          break;
      }
    } catch (_) {
      // Báo trạng thái lỗi để UI kết thúc thay vì để cuộc gọi quay vòng vô hạn.
      _emit(RtcState.failed);
    }
  }

  Future<void> _flushPendingCandidates() async {
    final pc = _pc;
    if (pc == null) return;
    for (final c in List.of(_pendingCandidates)) {
      try {
        await pc.addCandidate(c);
      } catch (_) {
        // bỏ qua candidate lỗi
      }
    }
    _pendingCandidates.clear();
  }

  // ===== Điều khiển =====
  bool get micOn =>
      localStream?.getAudioTracks().any((t) => t.enabled) ?? false;

  bool get cameraOn =>
      localStream?.getVideoTracks().any((t) => t.enabled) ?? false;

  void setMic(bool on) {
    for (final t in localStream?.getAudioTracks() ?? []) {
      t.enabled = on;
    }
  }

  void setCamera(bool on) {
    for (final t in localStream?.getVideoTracks() ?? []) {
      t.enabled = on;
    }
  }

  Future<void> setSpeaker(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (_) {
      // thiết bị không hỗ trợ đổi loa
    }
  }

  /// Đóng peer connection, media track và các stream để giải phóng mic/camera.
  Future<void> dispose() async {
    _disposed = true;
    _readyForSignals = false;
    _emit(RtcState.closed);
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    try {
      await localStream?.dispose();
    } catch (_) {}
    localStream = null;
    remoteStream = null;
    await _stateCtrl.close();
    await _remoteCtrl.close();
  }
}
