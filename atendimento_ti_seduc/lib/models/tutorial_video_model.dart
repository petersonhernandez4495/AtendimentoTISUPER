// lib/models/tutorial_video_model.dart
class TutorialVideo {
  final String title;
  final String youtubeVideoId;
  final String description;

  TutorialVideo({
    required this.title,
    required this.youtubeVideoId,
    this.description = '',
  });
}