import 'package:equatable/equatable.dart';

sealed class VideoTeaserState extends Equatable {
  const VideoTeaserState();

  @override
  List<Object?> get props => [];
}

class VideoTeaserInitial extends VideoTeaserState {}

class VideoTeaserQueuing extends VideoTeaserState {}

class VideoTeaserPolling extends VideoTeaserState {
  const VideoTeaserPolling(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}

class VideoTeaserSuccess extends VideoTeaserState {
  const VideoTeaserSuccess(this.videoUrl);

  final String videoUrl;

  @override
  List<Object?> get props => [videoUrl];
}

class VideoTeaserFailure extends VideoTeaserState {
  const VideoTeaserFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
