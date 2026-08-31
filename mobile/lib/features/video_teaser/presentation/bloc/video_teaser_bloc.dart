import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/features/video_teaser/domain/usecases/poll_job_status_usecase.dart';
import 'package:kelal_studio/features/video_teaser/domain/usecases/queue_video_teaser_usecase.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_event.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_state.dart';

@injectable
class VideoTeaserBloc extends Bloc<VideoTeaserEvent, VideoTeaserState> {
  VideoTeaserBloc(this._queueVideoTeaserUseCase, this._pollJobStatusUseCase)
    : super(VideoTeaserInitial()) {
    on<StoryboardSubmitted>(_onStoryboardSubmitted);
    on<JobStatusChecked>(_onJobStatusChecked);
  }

  final QueueVideoTeaserUseCase _queueVideoTeaserUseCase;
  final PollJobStatusUseCase _pollJobStatusUseCase;
  Timer? _pollingTimer;

  Future<void> _onStoryboardSubmitted(
    StoryboardSubmitted event,
    Emitter<VideoTeaserState> emit,
  ) async {
    emit(VideoTeaserQueuing());

    final result = await _queueVideoTeaserUseCase(
      storyboardText: event.storyboardText,
      brandKitId: event.brandKitId,
    );

    result.when(
      ok: (job) {
        if (job.status == 'done') {
          // If it's somehow done immediately
          emit(VideoTeaserSuccess(_getMockVideoUrl(job.resultAssetId)));
        } else if (job.status == 'failed') {
          emit(const VideoTeaserFailure('Video generation failed to queue.'));
        } else {
          emit(VideoTeaserPolling(job.id));
          _startPolling(job.id);
        }
      },
      err: (failure) => emit(VideoTeaserFailure(failure.message)),
    );
  }

  Future<void> _onJobStatusChecked(
    JobStatusChecked event,
    Emitter<VideoTeaserState> emit,
  ) async {
    // Only poll if we are still supposed to be polling
    if (state is! VideoTeaserPolling) return;

    final result = await _pollJobStatusUseCase(event.jobId);

    result.when(
      ok: (job) {
        if (job.status == 'done') {
          _pollingTimer?.cancel();
          emit(VideoTeaserSuccess(_getMockVideoUrl(job.resultAssetId)));
        } else if (job.status == 'failed') {
          _pollingTimer?.cancel();
          emit(const VideoTeaserFailure('Video generation failed.'));
        }
        // If 'queued' or 'running', do nothing, stay in Polling state
      },
      err: (failure) {
        _pollingTimer?.cancel();
        emit(VideoTeaserFailure(failure.message));
      },
    );
  }

  void _startPolling(String jobId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      add(JobStatusChecked(jobId));
    });
  }

  // Mock URL helper as agreed in Open Questions
  String _getMockVideoUrl(String? assetId) {
    // Using Flutter's official sample video which is CORS-friendly for web
    return 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }
}
