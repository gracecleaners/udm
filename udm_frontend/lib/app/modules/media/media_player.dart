import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/udm_widgets.dart';

/// The surfaces where an embedded YouTube player can actually run: the mobile
/// and desktop app builds use a WebView, a browser build uses the frame
/// directly. Elsewhere (a Windows or Linux app build) there is no WebView
/// behind this widget, so the screen offers the recording's own address
/// instead of a black box.
bool get inlinePlaybackSupported =>
    kIsWeb ||
    const {
      TargetPlatform.android,
      TargetPlatform.fuchsia,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

/// The ministry's recording, played inside the app.
///
/// Nothing is faked here: the frame is YouTube's own player, so the student
/// gets the quality, captions and full-screen they know from YouTube, and the
/// ministry's channel stays the place the video lives. The widget reports two
/// things back — where the student has got to, and whether they finished — and
/// those are what make a long recording resume instead of restart.
class RecordingPlayer extends StatefulWidget {
  const RecordingPlayer({
    super.key,
    required this.videoId,
    this.startAt,
    this.onPosition,
    this.onEnded,
  });

  final String videoId;

  /// Where to begin, in seconds, taken from the student's saved place.
  final int? startAt;
  final ValueChanged<int>? onPosition;
  final VoidCallback? onEnded;

  @override
  State<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<RecordingPlayer> {
  late final YoutubePlayerController _player;
  StreamSubscription<YoutubeVideoState>? _positionSubscription;
  StreamSubscription<YoutubePlayerValue>? _valueSubscription;
  YoutubePlayerValue _value = YoutubePlayerValue();
  int _lastReported = 0;

  /// A position is only worth a write when it has really moved: a recording
  /// left open on one frame should not ask the server to store the same number
  /// once a second.
  static const int _reportStride = 5;

  @override
  void initState() {
    super.initState();
    _lastReported = widget.startAt ?? 0;
    _player = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      // Cued, not started: a student who scrolls past a recording has not
      // asked to spend their data on it yet.
      autoPlay: false,
      startSeconds: (widget.startAt ?? 0).toDouble(),
      params: YoutubePlayerParams(
        showFullscreenButton: true,
        // The teaching is the point, so the frame ends on the ministry's own
        // shelf rather than on YouTube's next-video wall.
        showVideoAnnotations: false,
        strictRelatedVideos: true,
        playsInline: true,
      ),
    );
    _positionSubscription = _player.videoStateStream.listen((state) {
      final seconds = state.position.inSeconds;
      if ((seconds - _lastReported).abs() < _reportStride) return;
      _lastReported = seconds;
      widget.onPosition?.call(seconds);
    });
    _valueSubscription = _player.stream.listen((value) {
      if (mounted) setState(() => _value = value);
      if (value.playerState == PlayerState.ended) widget.onEnded?.call();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _valueSubscription?.cancel();
    _player.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(RecordingPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different recording under the same widget means the student moved on
    // from the shelf list; re-cue rather than leave the old frame up.
    if (oldWidget.videoId != widget.videoId) {
      _lastReported = widget.startAt ?? 0;
      _player.cueVideoById(
        videoId: widget.videoId,
        startSeconds: (widget.startAt ?? 0).toDouble(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_value.error != YoutubeError.none) {
      return _PlayerProblem(videoId: widget.videoId, problem: _value.error);
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: YoutubePlayer(
          controller: _player,
          // Inside a scrolling page the player must not swallow the swipe
          // that leaves it: only the play control takes a gesture.
          enableFullScreenOnVerticalDrag: false,
        ),
      ),
    );
  }
}

/// YouTube refusing the frame. Each reason is stated in the student's own
/// terms, because "video unavailable" tells them nothing about whether the
/// recording, the ministry, or their phone is the problem.
class _PlayerProblem extends StatelessWidget {
  const _PlayerProblem({required this.videoId, required this.problem});

  final String videoId;
  final YoutubeError problem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.play_disabled_rounded,
            size: 40,
            tone: IconBadgeTone.warning,
            filled: false,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'This recording will not play here',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                AppText(_reason, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton.icon(
            key: const Key('udm.openOnYouTube'),
            onPressed: () => openOnYouTube(videoId),
            icon: const Icon(AppIcons.external, size: 16),
            label: const AppText('Open'),
          ),
        ],
      ),
    );
  }

  String get _reason => switch (problem) {
    YoutubeError.notEmbeddable ||
    YoutubeError.sameAsNotEmbeddable ||
    YoutubeError.sameAsNotEmbeddable2 ||
    YoutubeError.unknown =>
      'The owner of this recording does not allow it to play inside other apps.',
    YoutubeError.videoNotFound ||
    YoutubeError.cannotFindVideo ||
    YoutubeError.invalidParam =>
      'YouTube has nothing at this address — the recording may be private or taken down. Tell the ministry team so the link can be fixed.',
    YoutubeError.html5Error =>
      'The video engine on this device cannot play this recording.',
    YoutubeError.none => 'YouTube did not play this recording.',
  };
}

/// The recording's own address on YouTube, which is the one link that still
/// works when the embedded frame is refused.
Future<void> openOnYouTube(String videoId) async {
  final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _couldNotOpen();
  } on Exception {
    _couldNotOpen();
  }
}

void _couldNotOpen() => Get.snackbar(
  'Could not open YouTube',
  'No app on this device could open this recording.',
);

