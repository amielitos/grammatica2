import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grammatica/widgets/responsive_dialog.dart';
import 'package:grammatica/models/notification.dart';
import 'package:grammatica/widgets/notification_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const testWidths = [320.0, 360.0, 392.0, 412.0];
  const testScales = [1.0, 1.3, 2.0];

  group('Responsive Layout & Dialog Tests (Zero Overflow Guarantee)', () {
    for (final width in testWidths) {
      for (final scale in testScales) {
        testWidgets('ResponsiveDialog renders with zero overflow at ${width}dp and scale $scale', (tester) async {
          tester.view.physicalSize = Size(width * 2.0, 800.0 * 2.0);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                home: Scaffold(
                  body: ResponsiveDialog(
                    title: 'Testing Very Long Dialog Title That Might Wrap Extensively Across Multiple Rows',
                    subtitle: 'Detailed subtitle describing the actions and state of the modal',
                    actions: [
                      TextButton(onPressed: () {}, child: const Text('Cancel')),
                      FilledButton(onPressed: () {}, child: const Text('Confirm Action')),
                    ],
                    child: Column(
                      children: List.generate(
                        10,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('Content row $i with some descriptive text'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('NotificationDetailDialog renders with zero overflow at ${width}dp and scale $scale', (tester) async {
          tester.view.physicalSize = Size(width * 2.0, 800.0 * 2.0);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final notification = NotificationModel(
            id: 'notif_1',
            uid: 'user_1',
            type: NotificationType.lessonUpload,
            title: 'New Lesson: Comprehensive Sentence Mechanics and Predicate Grammar Analysis',
            message: 'Your educator uploaded "Comprehensive Sentence Mechanics and Predicate Grammar Analysis" with interactive quizzes and companion materials.',
            createdAt: DateTime.now(),
          );

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                home: Scaffold(
                  body: NotificationDetailDialog(notification: notification),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
