import 'package:equatable/equatable.dart';

sealed class VideoTeaserEvent extends Equatable {
  const VideoTeaserEvent();

  @override
  List<Object?> get props => [];
}

class StoryboardSubmitted extends VideoTeaserEvent {
  const StoryboardSubmitted({
    required this.storyboardText,
    required this.brandKitId,
  });

  final String storyboardText;
  final String brandKitId;

  @override
  List<Object?> get props => [storyboardText, brandKitId];
}

class JobStatusChecked extends VideoTeaserEvent {
  const JobStatusChecked(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}
