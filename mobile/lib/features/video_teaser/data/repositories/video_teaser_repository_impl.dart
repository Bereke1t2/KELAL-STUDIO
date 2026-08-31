import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/video_teaser/data/datasources/video_teaser_remote_data_source.dart';
import 'package:kelal_studio/features/video_teaser/domain/entities/job.dart';
import 'package:kelal_studio/features/video_teaser/domain/repositories/video_teaser_repository.dart';

@LazySingleton(as: VideoTeaserRepository)
class VideoTeaserRepositoryImpl implements VideoTeaserRepository {
  VideoTeaserRepositoryImpl(this._remoteDataSource);

  // ignore: unused_field — kept for real backend integration
  final VideoTeaserRemoteDataSource _remoteDataSource;

  int _pollCount = 0;

  @override
  Future<Result<Failure, Job>> queueVideoTeaser({
    required String storyboardText,
    required String brandKitId,
  }) async {
    // TODO(backend): replace mock with real API call below.
    _pollCount = 0;
    await Future<void>.delayed(const Duration(seconds: 1));
    return const Result.ok(Job(id: 'mock-job-id', status: 'queued'));

    // REAL IMPLEMENTATION:
    // final request = GenerateVideoRequest(
    //   storyboardText: storyboardText,
    //   brandKitId: brandKitId,
    // );
    // final jobModel =
    //     await _remoteDataSource.generateVideo(request);
    // return Result.ok(Job(
    //   id: jobModel.id,
    //   status: jobModel.status,
    //   resultAssetId: jobModel.resultAssetId,
    // ));
  }

  @override
  Future<Result<Failure, Job>> getJobStatus(String jobId) async {
    // TODO(backend): replace mock with real API call below.
    _pollCount++;
    await Future<void>.delayed(const Duration(seconds: 1));
    if (_pollCount >= 2) {
      return const Result.ok(
        Job(id: 'mock-job-id', status: 'done', resultAssetId: 'mock-asset-123'),
      );
    }
    return const Result.ok(Job(id: 'mock-job-id', status: 'running'));

    // REAL IMPLEMENTATION:
    // final jobModel =
    //     await _remoteDataSource.getJobStatus(jobId);
    // return Result.ok(Job(
    //   id: jobModel.id,
    //   status: jobModel.status,
    //   resultAssetId: jobModel.resultAssetId,
    // ));
  }
}
