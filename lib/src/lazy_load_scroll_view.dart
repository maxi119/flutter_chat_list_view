import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum LoadingStatus { loading, stable }

class LazyLoadScrollController {
  LoadingStatus loadMoreStatus = LoadingStatus.stable;

  LazyLoadScrollController();

  void dispose() {}
}

/// Wrapper around a [Scrollable] which triggers [onEndOfPage]/[onStartOfPage] the Scrollable
/// reaches to the start or end of the view extent.
class LazyLoadScrollView extends StatefulWidget {
  /// Creates a new instance of [LazyLoadScrollView]. The parameter [child]
  /// must be supplied and not null.
  const LazyLoadScrollView({
    Key? key,
    required this.child,
    this.controller,
    this.onStartOfPage,
    this.onEndOfPage,
    this.onPageScrollStart,
    this.onPageScrollEnd,
    this.loadScrollOffset = 100,
  })  : assert(child != null),
        super(key: key);

  final LazyLoadScrollController? controller;

  /// The [Widget] that this widget watches for changes on
  final Widget child;

  /// Called when the [child] reaches the start of the list
  final AsyncCallback? onStartOfPage;

  /// Called when the [child] reaches the end of the list
  final AsyncCallback? onEndOfPage;

  /// Called when the list scrolling starts
  final VoidCallback? onPageScrollStart;

  /// Called when the list scrolling ends
  final VoidCallback? onPageScrollEnd;

  /// The offset to take into account when triggering [onEndOfPage]/[onStartOfPage] in pixels
  final double loadScrollOffset;

  @override
  State<StatefulWidget> createState() => _LazyLoadScrollViewState();
}

class _LazyLoadScrollViewState extends State<LazyLoadScrollView> {
  LazyLoadScrollController? _controller;
  double _scrollPosition = 0;

  int _lastTriggerOnStartPage = 0;
  int _lastTriggerOnEndPage = 0;

  @override
  void initState() {
    _controller = widget.controller ?? LazyLoadScrollController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: _onNotification,
        child: widget.child,
      );

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller?.dispose();
    }
    super.dispose();
  }

  bool _onNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      if (widget.onPageScrollStart != null) {
        widget.onPageScrollStart?.call();
        return true;
      }
    }
    if (notification is ScrollEndNotification) {
      if (widget.onPageScrollEnd != null) {
        widget.onPageScrollEnd?.call();
        return true;
      }
    }
    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      final loadScrollOffset = widget.loadScrollOffset;

      final extentBefore = notification.metrics.extentBefore;
      final extentAfter = notification.metrics.extentAfter;
      final scrollingDown = _scrollPosition < pixels;

      if (scrollingDown) {
        if (extentAfter <= loadScrollOffset) {
          _onEndOfPage();
          return true;
        }
      } else {
        if (extentBefore <= loadScrollOffset) {
          _onStartOfPage();
          return true;
        }
      }

      _scrollPosition = pixels;
    }
    return false;
  }

  void _onEndOfPage() {
    if (DateTime.now().millisecondsSinceEpoch - _lastTriggerOnEndPage < 1000) return;
    if (_controller!.loadMoreStatus == LoadingStatus.stable) {
      if (widget.onEndOfPage != null) {
        _controller!.loadMoreStatus = LoadingStatus.loading;
        _lastTriggerOnEndPage = DateTime.now().millisecondsSinceEpoch;
        widget.onEndOfPage!().then((value) => _waitNextBuild()).whenComplete(() {
          _controller!.loadMoreStatus = LoadingStatus.stable;
        });
      }
    }
  }

  void _onStartOfPage() {
    if (DateTime.now().millisecondsSinceEpoch - _lastTriggerOnStartPage < 1000) return;
    if (_controller!.loadMoreStatus == LoadingStatus.stable) {
      if (widget.onStartOfPage != null) {
        _controller!.loadMoreStatus = LoadingStatus.loading;
        _lastTriggerOnStartPage = DateTime.now().millisecondsSinceEpoch;
        widget.onStartOfPage!().then((value) => _waitNextBuild()).whenComplete(() {
          _controller!.loadMoreStatus = LoadingStatus.stable;
        });
      }
    }
  }

  Future<void> _waitNextBuild() async {
    final Completer completer = Completer();
    await Future.delayed(Duration(milliseconds: 500));
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      completer.complete();
    });
    await completer.future.timeout(Duration(milliseconds: 500), onTimeout: () {});
  }
}
