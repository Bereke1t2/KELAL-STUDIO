import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/video_teaser/domain/entities/job.dart';
import 'package:kelal_studio/features/video_teaser/domain/usecases/poll_job_status_usecase.dart';
import 'package:kelal_studio/features/video_teaser/domain/usecases/queue_video_teaser_usecase.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_bloc.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_event.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_state.dart';
import 'package:mocktail/mocktail.dart';

class MockQueueVideoTeaserUseCase extends Mock
    implements QueueVideoTeaserUseCase {}

class MockPollJobStatusUseCase extends Mock implements PollJobStatusUseCase {}

void main() {
  late MockQueueVideoTeaserUseCase mockQueueUseCase;
  late MockPollJobStatusUseCase mockPollUseCase;
  late VideoTeaserBloc bloc;

  setUp(() {
    mockQueueUseCase = MockQueueVideoTeaserUseCase();
    mockPollUseCase = MockPollJobStatusUseCase();
    bloc = VideoTeaserBloc(mockQueueUseCase, mockPollUseCase);
  });

  tearDown(() {
    bloc.close();
  });

  group('VideoTeaserBloc', () {
    const storyboardText = 'Test storyboard';
    const brandKitId = 'brand-id-123';
    const jobId = 'job-id-123';

    test('initial state is VideoTeaserInitial', () {
      expect(bloc.state, isA<VideoTeaserInitial>());
    });

    blocTest<VideoTeaserBloc, VideoTeaserState>(
      'emits [VideoTeaserQueuing, VideoTeaserPolling] '
      'when StoryboardSubmitted succeeds',
      build: () {
        when(
          () => mockQueueUseCase(
            storyboardText: storyboardText,
            brandKitId: brandKitId,
          ),
        ).thenAnswer(
          (_) async => const Result.ok(Job(id: jobId, status: 'queued')),
        );
        return bloc;
      },
      act: (bloc) => bloc.add(
        const StoryboardSubmitted(
          storyboardText: storyboardText,
          brandKitId: brandKitId,
        ),
      ),
      expect: () => [
        isA<VideoTeaserQueuing>(),
        const VideoTeaserPolling(jobId),
      ],
    );

    blocTest<VideoTeaserBloc, VideoTeaserState>(
      'emits [VideoTeaserSuccess] when JobStatusChecked returns done',
      build: () {
        when(() => mockPollUseCase(jobId)).thenAnswer(
          (_) async => const Result.ok(
            Job(id: jobId, status: 'done', resultAssetId: 'asset-123'),
          ),
        );
        return bloc;
      },
      seed: () => const VideoTeaserPolling(jobId),
      act: (bloc) => bloc.add(const JobStatusChecked(jobId)),
      expect: () => [isA<VideoTeaserSuccess>()],
    );
  });
}
