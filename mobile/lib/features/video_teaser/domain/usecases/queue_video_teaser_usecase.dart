import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/video_teaser/domain/entities/job.dart';
import 'package:kelal_studio/features/video_teaser/domain/repositories/video_teaser_repository.dart';

@injectable
class QueueVideoTeaserUseCase {
  QueueVideoTeaserUseCase(this._repository);

  final VideoTeaserRepository _repository;

  Future<Result<Failure, Job>> call({
    required String storyboardText,
    required String brandKitId,
  }) {
    return _repository.queueVideoTeaser(
      storyboardText: storyboardText,
      brandKitId: brandKitId,
    );
  }
}
