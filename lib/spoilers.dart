import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'spoiler.dart';

class SpoilersDetails {
  bool isOpened;

  double headerWidth;
  double headerHeight;

  List<double> headersWidth;
  List<double> headersHeight;

  double childWidth;
  double childHeight;

  List<double> childrenWidth;
  List<double> childrenHeight;

  SpoilersDetails(
      {this.isOpened,
      this.headerWidth,
      this.headerHeight,
      this.headersWidth,
      this.headersHeight,
      this.childWidth,
      this.childHeight,
      this.childrenWidth,
      this.childrenHeight});
}

typedef OnReady = Function(SpoilersDetails);
typedef OnUpdate = Function(SpoilersDetails);

class Spoilers extends StatefulWidget {
  final Widget header;
  final List<Spoiler> children;

  final bool isOpened;

  final Curve openCurve;
  final Curve closeCurve;

  final Duration duration;

  final bool waitFirstCloseAnimationBeforeOpen;

  final OnReady onReadyCallback;
  final OnUpdate onUpdateCallback;

  const Spoilers(
      {this.header,
      this.children,
      this.isOpened = false,
      this.waitFirstCloseAnimationBeforeOpen = false,
      this.duration,
      this.onReadyCallback,
      this.onUpdateCallback,
      this.openCurve = Curves.easeOutExpo,
      this.closeCurve = Curves.easeInExpo});

  @override
  SpoilersState createState() => SpoilersState();
}

class SpoilersState extends State<Spoilers> with TickerProviderStateMixin {
  double headerWidth;
  double headerHeight;

  double childWidth;
  double childHeight;

  final spoilersHeadersWidth = <double>[];
  final spoilersHeadersHeight = <double>[];

  final spoilersChildrenWidth = <double>[];
  final spoilersChildrenHeight = <double>[];

  AnimationController childHeightAnimationController;
  Animation<double> childHeightAnimation;

  StreamController<bool> isReadyController = StreamController();
  Stream<bool> isReady;

  StreamController<bool> isOpenController = StreamController();
  Stream<bool> isOpen;

  bool isOpened;

  List<StreamController<SpoilerDetails>> childrenOnUpdateEvents = [];
  List<StreamController<SpoilerDetails>> childrenOnReadyEvents = [];
  List<Spoiler> children;

  @override
  void initState() {
    super.initState();

    children =
        createChildrenCallbacks(widget.children == null ? [] : widget.children);

    /// child - need to know whose events.
    for (Spoiler child in children) {
      final indexOfSpoilerChild = children.indexOf(child);

      // ignore: close_sinks
      final childrenUpdateEvents = childrenOnUpdateEvents[indexOfSpoilerChild];

      childrenUpdateEvents.stream.listen((details) {
        spoilersChildrenHeight[indexOfSpoilerChild] = details.childHeight;
        double spoilersHeight = 0;

        spoilersHeight +=
            spoilersHeadersHeight.fold(0, (first, second) => first + second);

        spoilersHeight +=
            spoilersChildrenHeight.fold(0, (first, second) => first + second);

        childHeightAnimation = childHeightAnimation
            .drive(Tween(begin: spoilersHeight, end: spoilersHeight));
        childHeightAnimationController.reset();
      });
    }

    isOpened = widget.isOpened;
    isReady = isReadyController.stream.asBroadcastStream();
    isOpen = isOpenController.stream.asBroadcastStream();

    childHeightAnimationController = AnimationController(
        duration: widget.duration != null
            ? widget.duration
            : Duration(milliseconds: 400),
        vsync: this);

    childHeightAnimation = CurvedAnimation(
        parent: childHeightAnimationController,
        curve: widget.openCurve,
        reverseCurve: widget.closeCurve);

    final spoilersDetails = <SpoilerDetails>[];

    final spoilersDetailsQueue =
        Iterable<Future>.generate(children.length, (index) async {
      // ignore: close_sinks
      final spoilerReadyEvents = childrenOnReadyEvents[index];

      final details = await spoilerReadyEvents.stream.first;
      spoilersDetails.add(details);
    });

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      headerWidth = _headerKey.currentContext.size.width;
      headerHeight = _headerKey.currentContext.size.height;

      childWidth = _childKey.currentContext.size.width;
      childHeight = _childKey.currentContext.size.height;

      if (spoilersDetailsQueue.isNotEmpty) {
        await Future.wait(spoilersDetailsQueue);
      }

      for (SpoilerDetails details in spoilersDetails) {
        spoilersHeadersWidth.add(details.headerWidth);
        spoilersHeadersHeight.add(details.headerHeight);

        if (details.isOpened) {
          spoilersChildrenWidth.add(details.childWidth);
          spoilersChildrenHeight.add(details.childHeight);
        } else {
          spoilersChildrenWidth.add(0);
          spoilersChildrenHeight.add(0);
        }
      }

      prepareAnimation().then((_) => updateCallbacks());
    });
  }

  void updateCallbacks() {
    if (widget.onUpdateCallback != null) {
      childHeightAnimation.addListener(() => widget.onUpdateCallback(
          SpoilersDetails(
              isOpened: isOpened,
              headerWidth: headerWidth,
              headerHeight: headerHeight,
              headersWidth: spoilersHeadersWidth,
              headersHeight: spoilersHeadersHeight,
              childWidth: childWidth,
              childHeight: childHeightAnimation.value,
              childrenWidth: spoilersChildrenWidth,
              childrenHeight: spoilersChildrenHeight)));
    }

    if (widget.onReadyCallback != null) {
      widget.onReadyCallback(SpoilersDetails(
          isOpened: isOpened,
          headerWidth: headerWidth,
          headerHeight: headerHeight,
          headersWidth: spoilersHeadersWidth,
          headersHeight: spoilersHeadersHeight,
          childWidth: childWidth,
          childHeight: childHeight,
          childrenWidth: spoilersChildrenWidth,
          childrenHeight: spoilersChildrenHeight));
    }
  }

  double getSpoilersHeight() {
    double spoilersHeight = 0;
    spoilersHeight +=
        spoilersHeadersHeight.fold(0, (first, second) => first + second);
    spoilersHeight +=
        spoilersChildrenHeight.fold(0, (first, second) => first + second);
    return spoilersHeight;
  }

  Future<void> prepareAnimation() async {
    isReadyController.add(true);

    double spoilersHeight = 0;

    spoilersHeight +=
        spoilersHeadersHeight.fold(0, (first, second) => first + second);

    spoilersHeight +=
        spoilersChildrenHeight.fold(0, (first, second) => first + second);

    childHeightAnimation = childHeightAnimation
        .drive(Tween(begin: 0.toDouble(), end: spoilersHeight));
    childHeightAnimationController.reset();

    try {
      if (widget.waitFirstCloseAnimationBeforeOpen) {
        if (isOpened) {
          await childHeightAnimationController.forward().orCancel;
        } else {
          await childHeightAnimationController.forward().orCancel.whenComplete(
              () => childHeightAnimationController.reverse().orCancel);
        }
      } else {
        if (isOpened) {
          await childHeightAnimationController.forward().orCancel;
        } else {
          await childHeightAnimationController.reverse().orCancel;
        }
      }
    } on TickerCanceled {
      // the animation got canceled, probably because we were disposed
    }
  }

  @override
  void dispose() {
    childHeightAnimationController.dispose();
    isOpenController.close();
    isReadyController.close();
    childrenOnReadyEvents.forEach((controller) => controller.close());
    childrenOnUpdateEvents.forEach((controller) => controller.close());
    super.dispose();
  }

  List<Spoiler> createChildrenCallbacks(List<Spoiler> spoilers) {
    final spoilersWithDetailsControllers = <Spoiler>[];

    for (Spoiler spoiler in spoilers) {
      final detailsReadyController = StreamController<SpoilerDetails>();
      final detailsUpdateController = StreamController<SpoilerDetails>();

      final updatedSpoiler = Spoiler(
        onReadyCallback: (details) {
          if (spoiler.onReadyCallback != null) spoiler.onReadyCallback(details);
          detailsReadyController.add(details);
        },
        onUpdateCallback: (details) {
          if (spoiler.onUpdateCallback != null) {
            spoiler.onUpdateCallback(details);
          }

          detailsUpdateController.add(details);
        },
        header: spoiler.header,
        child: spoiler.child,
        duration: spoiler.duration,
        isOpened: spoiler.isOpened,
        openCurve: spoiler.openCurve,
        closeCurve: spoiler.closeCurve,
        waitFirstCloseAnimationBeforeOpen:
            spoiler.waitFirstCloseAnimationBeforeOpen,
      );

      childrenOnReadyEvents.add(detailsReadyController);
      childrenOnUpdateEvents.add(detailsUpdateController);

      spoilersWithDetailsControllers.add(updatedSpoiler);
    }

    return spoilersWithDetailsControllers;
  }

  Future<void> toggle() async {
    try {
      isOpened = isOpened ? false : true;

      isOpenController.add(isOpened);

      double spoilersHeight = 0;

      spoilersHeight +=
          spoilersHeadersHeight.fold(0, (first, second) => first + second);

      spoilersHeight +=
          spoilersChildrenHeight.fold(0, (first, second) => first + second);

      childHeightAnimation = CurvedAnimation(
              parent: childHeightAnimationController,
              curve: widget.openCurve,
              reverseCurve: widget.closeCurve)
          .drive(isOpened
              ? Tween(begin: 0.0, end: spoilersHeight)
              : Tween(begin: spoilersHeight, end: 0.0));

      childHeightAnimationController.reset();

      await childHeightAnimationController.forward().orCancel;
    } on TickerCanceled {
      // the animation got canceled, probably because we were disposed
    }
  }

  final GlobalKey _headerKey = GlobalKey(debugLabel: 'header');
  final GlobalKey _childKey = GlobalKey(debugLabel: 'child');

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            onTap: toggle,
            child: Container(
              key: Key('spoilers_header'),
              child: Container(
                key: _headerKey,
                child: widget.header != null
                    ? widget.header
                    : _buildDefaultHeader(),
              ),
            ),
          ),
          StreamBuilder<bool>(
              stream: isReady,
              initialData: false,
              builder: (context, snapshot) {
                if (snapshot.data) {
                  return AnimatedBuilder(
                    animation: childHeightAnimation,
                    builder: (BuildContext context, Widget child) => Container(
                      key: isOpened
                          ? Key('spoilers_child_opened')
                          : Key('spoilers_child_closed'),
                      height: childHeightAnimation.value > 0
                          ? childHeightAnimation.value
                          : 0,
                      child: Wrap(
                        children: <Widget>[
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                children.isNotEmpty ? children : [Container()],
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return Container(
                    key: isOpened
                        ? Key('spoilers_child_opened')
                        : Key('spoilers_child_closed'),
                    child: Container(
                      key: _childKey,
                      child: Wrap(
                        children: <Widget>[
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                children.isNotEmpty ? children : [Container()],
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }),
        ],
      );

  Widget _buildDefaultHeader() => StreamBuilder<bool>(
      stream: isOpen,
      initialData: isOpened,
      builder: (context, snapshot) => Container(
          margin: EdgeInsets.all(10),
          height: 20,
          width: 20,
          child: Center(
              child: Center(child: snapshot.data ? Text('-') : Text('+')))));
}
