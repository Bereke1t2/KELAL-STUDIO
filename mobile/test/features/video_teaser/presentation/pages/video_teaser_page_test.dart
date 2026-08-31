import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_bloc.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_event.dart';
import 'package:kelal_studio/features/video_teaser/presentation/bloc/video_teaser_state.dart';
import 'package:kelal_studio/features/video_teaser/presentation/pages/video_teaser_page.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoTeaserBloc extends MockBloc<VideoTeaserEvent, VideoTeaserState>
    implements VideoTeaserBloc {}

void main() {
  late MockVideoTeaserBloc mockBloc;

  setUp(() {
    mockBloc = MockVideoTeaserBloc();
    GetIt.I.registerFactory<VideoTeaserBloc>(() => mockBloc);
  });

  tearDown(() {
    GetIt.I.reset();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(theme: AppTheme.light(), home: const VideoTeaserPage());
  }

  testWidgets('renders initial UI correctly', (tester) async {
    when(() => mockBloc.state).thenReturn(VideoTeaserInitial());

    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.text('Video Teaser'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Generate Video'), findsOneWidget);
  });

  testWidgets('shows loading indicator when queuing', (tester) async {
    when(() => mockBloc.state).thenReturn(VideoTeaserQueuing());

    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
