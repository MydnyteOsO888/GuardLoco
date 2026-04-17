import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'api_service.dart';

/// WebRTC peer-to-peer streaming from ESP32-CAM.
/// Backend (FastAPI) acts as signaling server.
/// Uses STUN/TURN for NAT traversal.
/// Per research doc: low-latency SRTP encrypted channel.
class WebRtcService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;

  final _remoteStreamController =
      StreamController<MediaStream>.broadcast();

  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
  bool get isConnected => _peerConnection != null;

  // ── ICE / STUN / TURN config ──────────────────────────────
  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Add your TURN server for production NAT traversal:
      // {
      //   'urls': 'turn:your-turn-server.com:3478',
      //   'username': 'user',
      //   'credential': 'password',
      // },
    ],
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': 'all',
  };

  static const Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  // ── Connect ───────────────────────────────────────────────
  Future<void> connect() async {
    await dispose();

    // 1. Create peer connection
    _peerConnection = await createPeerConnection(_rtcConfig);

    // 2. Listen for remote stream from ESP32-CAM
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _remoteStreamController.add(_remoteStream!);
      }
    };

    // 3. ICE candidate → send to signaling server
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
      await ApiService().sendIceCandidate({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    // 4. Connection state logging
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      _connectionStateController.add(state);
    };

    // 5. Create offer → send to server → get answer
    final offer = await _peerConnection!.createOffer(_constraints);
    await _peerConnection!.setLocalDescription(offer);

    final answerData = await ApiService().createOffer({
      'sdp': offer.sdp,
      'type': offer.type,
    });

    final answer = RTCSessionDescription(
      answerData['sdp'] as String,
      answerData['type'] as String,
    );
    await _peerConnection!.setRemoteDescription(answer);

    // 6. Poll for remote ICE candidates
    _startIceCandidatePolling();
  }

  // ── ICE Candidate Polling ─────────────────────────────────
  Timer? _icePollTimer;
  final Set<String> _receivedCandidates = {};

  void _startIceCandidatePolling() {
    _icePollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) async {
        try {
          final candidates = await ApiService().getIceCandidates();
          for (final c in candidates) {
            final key = '${c['sdpMid']}_${c['sdpMLineIndex']}_${c['candidate']}';
            if (!_receivedCandidates.contains(key)) {
              _receivedCandidates.add(key);
              await _peerConnection?.addCandidate(
                RTCIceCandidate(
                  c['candidate'] as String,
                  c['sdpMid'] as String,
                  c['sdpMLineIndex'] as int,
                ),
              );
            }
          }
        } catch (_) {}
      },
    );
  }

  // ── Connection State Stream ────────────────────────────────
  final _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();
  Stream<RTCPeerConnectionState> get connectionState =>
      _connectionStateController.stream;

  // ── Disconnect (keeps stream controllers alive for reconnect) ─
  Future<void> disconnect() async {
    _icePollTimer?.cancel();
    _receivedCandidates.clear();
    await _remoteStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    _remoteStream = null;
  }

  // ── Dispose ───────────────────────────────────────────────
  Future<void> dispose() async {
    await disconnect();
    await _remoteStreamController.close();
    await _connectionStateController.close();
  }
}
