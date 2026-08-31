import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/video_teaser/domain/entities/job.dart';
import 'package:kelal_studio/features/video_teaser/domain/repositories/video_teaser_repository.dart';

@injectable
class PollJobStatusUseCase {
  PollJobStatusUseCase(this._repository);

  final VideoTeaserRepository _repository;

  Future<Result<Failure, Job>> call(String jobId) {
    return _repository.getJobStatus(jobId);
  }
}
