import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class LeftOnlyHorizontalDragGestureRecognizer extends HorizontalDragGestureRecognizer {
  LeftOnlyHorizontalDragGestureRecognizer({super.debugOwner});

  double _totalDx = 0.0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _totalDx = 0.0;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _totalDx += event.delta.dx;
      // If moving right (dx > 0), reject immediately so parent recognizer wins!
      if (_totalDx > kTouchSlop) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }
    }
    super.handleEvent(event);
  }
}

class LeftOnlyGestureDetector extends RawGestureDetector {
  LeftOnlyGestureDetector({
    super.key,
    required Widget child,
    GestureDragUpdateCallback? onUpdate,
    GestureDragEndCallback? onEnd,
  }) : super(
          gestures: {
            LeftOnlyHorizontalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<LeftOnlyHorizontalDragGestureRecognizer>(
              () => LeftOnlyHorizontalDragGestureRecognizer(),
              (instance) {
                instance.onUpdate = onUpdate;
                instance.onEnd = onEnd;
              },
            ),
          },
          child: child,
        );
}

void main() {
  testWidgets('LeftOnlyGestureDetector allows parent to receive right drag', (tester) async {
    bool parentSwipedRight = false;
    bool childSwipedLeft = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 0) {
                parentSwipedRight = true;
              }
            },
            child: SizedBox(
              width: 400,
              height: 400,
              child: LeftOnlyGestureDetector(
                onUpdate: (details) {
                  if (details.primaryDelta! < 0) {
                    childSwipedLeft = true;
                  }
                },
                child: Container(width: 400, height: 100, color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );

    // 1. Drag right over child
    await tester.fling(find.byType(Container), const Offset(200, 0), 1000);
    await tester.pumpAndSettle();
    print('Parent swiped right: $parentSwipedRight');
    expect(parentSwipedRight, isTrue);

    // 2. Drag left over child
    parentSwipedRight = false;
    await tester.fling(find.byType(Container), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    print('Child swiped left: $childSwipedLeft');
    expect(childSwipedLeft, isTrue);
  });
}
