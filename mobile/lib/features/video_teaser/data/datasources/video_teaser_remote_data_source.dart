import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/features/video_teaser/data/models/generate_video_request.dart';
import 'package:kelal_studio/features/video_teaser/data/models/job_model.dart';
import 'package:retrofit/retrofit.dart';

part 'video_teaser_remote_data_source.g.dart';

@RestApi()
@injectable
abstract class VideoTeaserRemoteDataSource {
  @factoryMethod
  factory VideoTeaserRemoteDataSource(Dio dio) = _VideoTeaserRemoteDataSource;

  @POST('/v1/generate/video')
  Future<JobModel> generateVideo(@Body() GenerateVideoRequest request);

  @GET('/v1/jobs/{id}')
  Future<JobModel> getJobStatus(@Path('id') String id);
}
