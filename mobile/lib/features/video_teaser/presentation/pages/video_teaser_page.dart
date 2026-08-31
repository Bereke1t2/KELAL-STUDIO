import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/theme/app_colors.dart';
import 'package:kelal_studio/core/theme/app_spacing.dart';
import 'package:kelal_studio/core/theme/app_typography.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_bloc.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_event.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_state.dart';
import 'package:kelal_studio/features/video_teaser/presentation/widgets/video_player_preview.dart';

class VideoTeaserPage extends StatelessWidget {
  const VideoTeaserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GetIt.I<VideoTeaserBloc>(),
      child: const _VideoTeaserView(),
    );
  }
}

class _VideoTeaserView extends StatefulWidget {
  const _VideoTeaserView();

  @override
  State<_VideoTeaserView> createState() => _VideoTeaserViewState();
}

class _VideoTeaserViewState extends State<_VideoTeaserView> {
  final _storyboardController = TextEditingController();

  // Mocked BrandKitID per Implementation Plan agreement
  final String _mockBrandKitId = '00000000-0000-0000-0000-000000000000';

  @override
  void dispose() {
    _storyboardController.dispose();
    super.dispose();
  }

  void _submitStoryboard(BuildContext context) {
    final text = _storyboardController.text.trim();
    if (text.isNotEmpty) {
      context.read<VideoTeaserBloc>().add(
        StoryboardSubmitted(storyboardText: text, brandKitId: _mockBrandKitId),
      );
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgCanvas,
      appBar: AppBar(
        backgroundColor: context.colors.bgCanvas,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Video Teaser',
          style: AppTypography.title.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create a video teaser from your storyboard.',
                style: AppTypography.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _storyboardController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter your 3-part storyboard...',
                  hintStyle: AppTypography.body.copyWith(
                    color: context.colors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.colors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: context.colors.primaryDefault,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              BlocConsumer<VideoTeaserBloc, VideoTeaserState>(
                listener: (context, state) {
                  if (state is VideoTeaserFailure) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.message)));
                  }
                },
                builder: (context, state) {
                  final isLoading =
                      state is VideoTeaserQueuing ||
                      state is VideoTeaserPolling;

                  return ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () => _submitStoryboard(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primaryDefault,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Generate Video',
                            style: AppTypography.title.copyWith(
                              color: Colors.white,
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              Expanded(
                child: BlocBuilder<VideoTeaserBloc, VideoTeaserState>(
                  builder: (context, state) {
                    if (state is VideoTeaserPolling) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Generating video... Polling Job: ${state.jobId}',
                            style: AppTypography.caption.copyWith(
                              color: context.colors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    } else if (state is VideoTeaserSuccess) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preview',
                            style: AppTypography.title.copyWith(
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ColoredBox(
                                color: Colors.black,
                                child: VideoPlayerPreview(
                                  videoUrl: state.videoUrl,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
