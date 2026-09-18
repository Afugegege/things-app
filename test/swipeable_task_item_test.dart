import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class LeftOnlyHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  final ValueGetter<bool> isOpen;

  LeftOnlyHorizontalDragGestureRecognizer({
    super.debugOwner,
    required this.isOpen,
  });

  double _totalDx = 0.0;
  bool _rejected = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _totalDx = 0.0;
    _rejected = false;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && !_rejected) {
      _totalDx += event.delta.dx;
      // If card is closed and user drags right, reject immediately so parent (screen swipe) wins!
      if (!isOpen() && _totalDx > kTouchSlop) {
        _rejected = true;
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }
    }
    super.handleEvent(event);
  }
}

class SwipeableTaskCard extends StatefulWidget {
  final Widget child;
  final List<Widget> actions;
  final bool enabled;

  const SwipeableTaskCard({
    super.key,
    required this.child,
    required this.actions,
    this.enabled = true,
  });

  @override
  State<SwipeableTaskCard> createState() => SwipeableTaskCardState();
}

class SwipeableTaskCardState extends State<SwipeableTaskCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragExtent = 0.0;

  double get _maxActionsWidth => widget.actions.length * 48.0;
  bool get isOpen => _controller.value > 0.05;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _dragExtent = _controller.value * _maxActionsWidth;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _maxActionsWidth <= 0) return;
    _dragExtent -= details.primaryDelta ?? 0.0;
    _dragExtent = _dragExtent.clamp(0.0, _maxActionsWidth);
    _controller.value = _dragExtent / _maxActionsWidth;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.enabled || _maxActionsWidth <= 0) return;
    final velocity = details.primaryVelocity ?? 0.0;
    if (velocity < -300 || _controller.value > 0.35) {
      _controller.animateTo(1.0, curve: Curves.easeOutCubic);
    } else {
      _controller.animateTo(0.0, curve: Curves.easeOutCubic);
    }
  }

  void close() {
    if (_controller.value > 0) {
      _controller.animateTo(0.0, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.actions.isEmpty) {
      return widget.child;
    }

    final gestureRecognizer = {
      LeftOnlyHorizontalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<
              LeftOnlyHorizontalDragGestureRecognizer>(
        () => LeftOnlyHorizontalDragGestureRecognizer(isOpen: () => isOpen),
        (instance) {
          instance.onStart = _handleDragStart;
          instance.onUpdate = _handleDragUpdate;
          instance.onEnd = _handleDragEnd;
        },
      ),
    };

    return RawGestureDetector(
      gestures: gestureRecognizer,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = _controller.value * _maxActionsWidth;
          return Stack(
            children: [
              // Background actions layer
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: widget.actions,
                ),
              ),
              // Front card layer
              Transform.translate(
                offset: Offset(-offset, 0),
                child: child,
              ),
            ],
          );
        },
        child: GestureDetector(
          onTap: () {
            if (_controller.value > 0) {
              close();
            }
          },
          child: widget.child,
        ),
      ),
    );
  }
}

void main() {
  testWidgets('SwipeableTaskCard allows parent right drag when closed, closes when open', (tester) async {
    bool scaffoldSwipedRight = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 0) {
                scaffoldSwipedRight = true;
              }
            },
            child: SizedBox(
              width: 400,
              height: 400,
              child: SwipeableTaskCard(
                actions: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.delete)),
                ],
                child: Container(width: 400, height: 80, color: Colors.blue, key: const Key('card_front')),
              ),
            ),
          ),
        ),
      ),
    );

    // 1. When closed: Drag RIGHT over the card -> Scaffold should receive swipe right!
    await tester.fling(find.byKey(const Key('card_front')), const Offset(200, 0), 1000);
    await tester.pumpAndSettle();
    expect(scaffoldSwipedRight, isTrue);

    // 2. Drag LEFT over the card -> card slides open!
    scaffoldSwipedRight = false;
    await tester.fling(find.byKey(const Key('card_front')), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(scaffoldSwipedRight, isFalse);
    expect(find.byIcon(Icons.edit), findsOneWidget);

    // 3. When open: Drag RIGHT over the card -> should close the card, NOT trigger scaffold swipe right!
    scaffoldSwipedRight = false;
    await tester.fling(find.byKey(const Key('card_front')), const Offset(200, 0), 1000);
    await tester.pumpAndSettle();
    expect(scaffoldSwipedRight, isFalse);

    // 4. Now closed again: Drag RIGHT -> Scaffold receives swipe right!
    await tester.fling(find.byKey(const Key('card_front')), const Offset(200, 0), 1000);
    await tester.pumpAndSettle();
    expect(scaffoldSwipedRight, isTrue);
  });
}
