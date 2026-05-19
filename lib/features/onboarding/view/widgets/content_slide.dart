import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../shared/theme/app_spacing.dart';

class ContentSlide extends StatefulWidget {
  final IconData icon;
  final String? videoAsset;
  final String titleKey;
  final String descriptionKey;

  const ContentSlide({
    super.key,
    required this.icon,
    this.videoAsset,
    required this.titleKey,
    required this.descriptionKey,
  });

  @override
  State<ContentSlide> createState() => _ContentSlideState();
}

class _ContentSlideState extends State<ContentSlide> {
  VideoPlayerController? _controller;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.videoAsset != null) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(widget.videoAsset!);
    try {
      await controller.initialize();
      controller
        ..setLooping(true)
        ..setVolume(0);
      await controller.play();
      if (mounted) {
        setState(() {
          _controller = controller;
          _videoReady = true;
        });
      } else {
        await controller.dispose();
      }
    } catch (e) {
      debugPrint('[ContentSlide] Video init error for ${widget.videoAsset}: $e');
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Widget visual;
    if (_videoReady && _controller != null) {
      visual = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      );
    } else {
      visual = Icon(widget.icon, size: 80, color: colorScheme.primary);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: visual,
          ),
          SizedBox(height: context.spacingLg),
          Text(
            widget.titleKey.tr(),
            style: TextStyle(
              fontSize: context.fontSizeLg,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.spacingMd),
          Text(
            widget.descriptionKey.tr(),
            style: TextStyle(
              fontSize: context.fontSizeSm,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
