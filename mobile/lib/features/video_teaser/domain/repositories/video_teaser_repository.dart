import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/video_teaser/domain/entities/job.dart';

abstract class VideoTeaserRepository {
  Future<Result<Failure, Job>> queueVideoTeaser({
    required String storyboardText,
    required String brandKitId,
  });

  Future<Result<Failure, Job>> getJobStatus(String jobId);
}
