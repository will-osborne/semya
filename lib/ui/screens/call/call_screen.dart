import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:semya/data/services/webrtc_service.dart';
import 'package:semya/domain/entities/call.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/call_provider.dart';
import 'package:semya/providers/providers.dart';
import 'package:semya/providers/user_provider.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.callId});

  final String callId;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _joinAttempted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final callState = ref.watch(callProvider);
    final call = callState.activeCall;
    final currentUserId = ref.watch(authProvider).user?.uid;
    final l10n = AppLocalizations.of(context)!;
    final webRtcService = ref.watch(webRtcServiceProvider);

    // If navigated here from a notification with no active call and
    // answerCall isn't already in progress, try to join.
    if (call == null && !_joinAttempted && !callState.isConnecting) {
      _joinAttempted = true;
      if (currentUserId != null) {
        // Defer to avoid modifying provider during build.
        Future.microtask(() {
          ref.read(callProvider.notifier)
            ..setCurrentUserId(currentUserId)
            ..joinCall(widget.callId);
        });
      }
    }

    // Navigate back when call ends.
    ref.listen<CallState>(callProvider, (prev, next) {
      if (prev?.activeCall != null && next.activeCall == null) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    // Resolve the other party's display name.
    final otherUserId = call != null
        ? (call.callerId == currentUserId ? call.calleeId : call.callerId)
        : null;
    final otherUserAsync = otherUserId != null
        ? ref.watch(userByIdProvider(otherUserId))
        : null;
    final displayName =
        otherUserAsync?.whenOrNull(data: (user) => user?.displayName) ??
        l10n.call;

    // Status text.
    String statusText;
    if (call == null) {
      statusText = '';
    } else if (call.status == CallStatus.ringing) {
      statusText = l10n.ringing;
    } else if (callState.isConnecting) {
      statusText = l10n.connecting;
    } else if (call.status == CallStatus.connected) {
      statusText = _formatDuration(callState.callDuration);
    } else {
      statusText = l10n.callEnded;
    }

    final showVideo = callState.isVideoEnabled || callState.hasRemoteVideo;

    return Scaffold(
      backgroundColor: showVideo ? Colors.black : colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Video or audio-only layout.
            if (showVideo)
              _buildVideoLayout(webRtcService, callState, displayName, statusText, theme)
            else
              _buildAudioLayout(displayName, statusText, theme, colorScheme),

            // Controls at the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildControls(callState, colorScheme, l10n, showVideo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioLayout(
    String displayName,
    String statusText,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Column(
        children: [
          const Spacer(flex: 2),
          CircleAvatar(
            radius: 48,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 48,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            displayName,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(flex: 3),
          const SizedBox(height: 120), // space for controls
        ],
      ),
    );
  }

  Widget _buildVideoLayout(
    WebRtcService webRtcService,
    CallState callState,
    String displayName,
    String statusText,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Remote video (full screen).
              if (callState.hasRemoteVideo)
                Positioned.fill(
                  child: RTCVideoView(
                    webRtcService.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 48,
                        child: Icon(Icons.person, size: 48),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statusText,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

              // Local video (picture-in-picture).
              if (callState.isVideoEnabled)
                Positioned(
                  top: 16,
                  right: 16,
                  width: 120,
                  height: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(
                      webRtcService.localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),

              // Name + status overlay when remote video is showing.
              if (callState.hasRemoteVideo)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          shadows: [
                            const Shadow(blurRadius: 4, color: Colors.black54),
                          ],
                        ),
                      ),
                      Text(
                        statusText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          shadows: [
                            const Shadow(blurRadius: 4, color: Colors.black54),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 120), // space for controls
      ],
    );
  }

  Widget _buildControls(
    CallState callState,
    ColorScheme colorScheme,
    AppLocalizations l10n,
    bool showVideo,
  ) {
    final bgActive = showVideo
        ? Colors.white.withValues(alpha: 0.3)
        : colorScheme.primaryContainer;
    final bgInactive = showVideo
        ? Colors.white.withValues(alpha: 0.1)
        : colorScheme.surfaceContainerHighest;
    final iconActive = showVideo ? Colors.white : colorScheme.onPrimaryContainer;
    final iconInactive = showVideo ? Colors.white : colorScheme.onSurface;
    final labelColor = showVideo ? Colors.white70 : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: showVideo
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              ),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute toggle.
          _CallButton(
            icon: callState.isMuted ? Icons.mic_off : Icons.mic,
            label: callState.isMuted ? l10n.unmute : l10n.mute,
            backgroundColor: callState.isMuted ? bgActive : bgInactive,
            iconColor: callState.isMuted ? iconActive : iconInactive,
            labelColor: labelColor,
            onTap: () => ref.read(callProvider.notifier).toggleMute(),
          ),

          // Video toggle.
          _CallButton(
            icon: callState.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: l10n.video,
            backgroundColor: callState.isVideoEnabled ? bgActive : bgInactive,
            iconColor: callState.isVideoEnabled ? iconActive : iconInactive,
            labelColor: labelColor,
            onTap: () => ref.read(callProvider.notifier).toggleVideo(),
          ),

          // Camera flip (only when video is on).
          if (callState.isVideoEnabled)
            _CallButton(
              icon: Icons.flip_camera_ios,
              label: l10n.flipCamera,
              backgroundColor: bgInactive,
              iconColor: iconInactive,
              labelColor: labelColor,
              onTap: () => ref.read(callProvider.notifier).switchCamera(),
            ),

          // Speaker toggle (only when video is off).
          if (!callState.isVideoEnabled && !Platform.isIOS)
            _CallButton(
              icon: callState.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              label: l10n.speaker,
              backgroundColor: callState.isSpeakerOn ? bgActive : bgInactive,
              iconColor: callState.isSpeakerOn ? iconActive : iconInactive,
              labelColor: labelColor,
              onTap: () => ref.read(callProvider.notifier).toggleSpeaker(),
            ),

          // Hang up.
          _CallButton(
            icon: Icons.call_end,
            label: l10n.end,
            backgroundColor: colorScheme.error,
            iconColor: colorScheme.onError,
            labelColor: labelColor,
            onTap: () => ref.read(callProvider.notifier).hangUp(),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

// ---------------------------------------------------------------------------
// Call action button
// ---------------------------------------------------------------------------

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 28,
            backgroundColor: backgroundColor,
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: labelColor ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
