import 'dart:developer';

import 'package:camera_works/camera_works.dart';
import 'package:flutter/material.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

import 'constants/constants.dart';
import 'exposure_point_widget.dart';

class CameraPage extends StatefulWidget {
  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController cameraController;
  var _lensType = CameraType.back;
  int _pointers = 0;
  final double _minAvailableZoom = 1.0;
  final double _maxAvailableZoom = 10.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  final ValueNotifier<Offset?> _lastExposurePoint =
      ValueNotifier<Offset?>(null);

  @override
  void initState() {
    super.initState();

    _requestPermission();

    cameraController = CameraController(_lensType);
    start();
  }

  _requestPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
    ].request();

    final info = statuses[Permission.storage].toString();
    print(info);
    _toastInfo(info);
  }

  _toastInfo(String info) {
    Fluttertoast.showToast(msg: info, toastLength: Toast.LENGTH_LONG);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (_pointers != 2) {
      return;
    }

    _currentScale = (_baseScale * details.scale)
        .clamp(_minAvailableZoom, _maxAvailableZoom);

    await cameraController.setZoomRatio(_currentScale);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text('Camera Demo'),
      // ),
      body: ValueListenableBuilder<double>(
        valueListenable: cameraController.zoomRatioNotifier,
        builder: (context, state, child) {
          return Listener(
              onPointerDown: (_) => _pointers++,
              onPointerUp: (_) => _pointers--,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                child: LayoutBuilder(
                    builder: (BuildContext c, BoxConstraints constraints) {
                      print('constraints: ' + constraints.toString());
                        return Stack(
                          children: [
                            CameraView(cameraController),
                            _exposureDetectorWidget(c, constraints),
                            _focusingAreaWidget(constraints),
                            // if (widget.enableZoom)
                            Positioned(
                              bottom: 120,
                              left: 0.0,
                              right: 0.0,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.black.withOpacity(0.6),
                                child: Center(
                                  child: Text(
                                    '${state.toStringAsFixed(1)}x',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              alignment: Alignment.bottomCenter,
                              margin: EdgeInsets.only(bottom: 32.0),
                              child: _buildControls(),
                            ),
                          ],
                        );
                    }),
              ));
        },
      ),
    );
  }

  Widget _focusingAreaWidget(BoxConstraints constraints) {
    Widget _buildFromPoint(Offset point) {
      final double _pointWidth = constraints.maxWidth / 5;
      final double _width = _pointWidth + 2;

      final bool _shouldReverseLayout = point.dx > constraints.maxWidth / 4 * 3;

      final double _effectiveLeft = math.min(
        constraints.maxWidth - _width,
        math.max(0, point.dx - _width / 2),
      );
      final double _effectiveTop = math.min(
        constraints.maxHeight - _pointWidth * 3,
        math.max(0, point.dy - _pointWidth * 3 / 2),
      );

      return Positioned(
        left: _effectiveLeft,
        top: _effectiveTop,
        width: _width,
        height: _pointWidth * 3,
        child: Row(
          textDirection:
              _shouldReverseLayout ? TextDirection.rtl : TextDirection.ltr,
          children: <Widget>[
            ExposurePointWidget(
              key: ValueKey<int>(currentTimeStamp),
              size: _pointWidth,
              color: Color(0xff00bc56),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<Offset?>(
      valueListenable: _lastExposurePoint,
      builder: (_, Offset? point, __) {
        if (point == null) {
          return const SizedBox.shrink();
        }
        return _buildFromPoint(point);
      },
    );
  }

  Widget _exposureDetectorWidget(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    return Positioned.fill(
      child: GestureDetector(
        onTapUp: (TapUpDetails d) => setExposureAndFocusPoint(d, constraints),
        behavior: HitTestBehavior.translucent,
        child: const SizedBox.expand(),
      ),
    );
  }

  /// Use the [details] point to set exposure and focus.
  /// 通过点击点的 [details] 设置曝光和对焦。
  Future<void> setExposureAndFocusPoint(
    TapUpDetails details,
    BoxConstraints constraints,
  ) async {
    // _isExposureModeDisplays.value = false;
    // Ignore point update when the new point is less than 8% and higher than
    // 92% of the screen's height.
    if (details.globalPosition.dy < constraints.maxHeight / 12 ||
        details.globalPosition.dy > constraints.maxHeight / 12 * 11) {
      return;
    }
    realDebugPrint(
      'Setting new exposure point ('
      'x: ${details.globalPosition.dx}, '
      'y: ${details.globalPosition.dy}'
      ')',
    );
    _lastExposurePoint.value = Offset(
      details.globalPosition.dx,
      details.globalPosition.dy,
    );

    print("CameraPicker - _lastExposurePoint dx: " + _lastExposurePoint.value!.dx.toString());
    print("CameraPicker  2- _lastExposurePoint dy: " + _lastExposurePoint.value!.dy.toString());
    await cameraController.setFocus(
        constraints,
        _lastExposurePoint.value!
        // _lastExposurePoint.value!.scale(
        //   1 / constraints.maxWidth,
        //   1 / constraints.maxHeight,
        // ),
      );
    // _restartPointDisplayTimer();
    // _currentExposureOffset.value = 0;
    // if (_exposureMode.value == ExposureMode.locked) {
    //   await controller.setExposureMode(ExposureMode.auto);
    //   _exposureMode.value = ExposureMode.auto;
    // }
    // controller.setExposurePoint(
    //   _lastExposurePoint.value!.scale(
    //     1 / constraints.maxWidth,
    //     1 / constraints.maxHeight,
    //   ),
    // );
    // if (controller.value.focusPointSupported == true) {
    //   controller.setFocusPoint(
    //     _lastExposurePoint.value!.scale(
    //       1 / constraints.maxWidth,
    //       1 / constraints.maxHeight,
    //     ),
    //   );
    // }
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
            iconSize: 16,
            icon: Icon(Icons.flip_camera_android, size: 32),
            color: Colors.blue,
            padding: EdgeInsets.zero,
            onPressed: () {
              switchCamera(
                  _lensType.index == 0 ? CameraType.back : CameraType.front);
            }),
        IconButton(
          iconSize: 70,
          icon: Icon(Icons.circle, size: 70),
          color: Colors.white,
          padding: EdgeInsets.zero,
          onPressed: takePicture,
        ),
        ValueListenableBuilder(
          valueListenable: cameraController.torchState,
          builder: (context, state, child) {
            return IconButton(
              iconSize: 16,
              icon: Icon(Icons.bolt, size: 32),
              padding: EdgeInsets.zero,
              color: state == FlashState.off ? Colors.grey : Colors.white,
              onPressed: () {
                if (state == FlashState.on) {
                  setFlash(FlashState.off);
                } else {
                  setFlash(FlashState.on);
                }
              },
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    stop();
    cameraController.dispose();
    _lastExposurePoint.dispose();
    super.dispose();
  }

  void start() async {
    try {
      await cameraController.startAsync();
    } on CameraException catch (e) {
      _showErrorSnackBar(e.message ?? '');
    } catch (e) {
      log(e.toString());
    }
  }

  void stop() {
    try {
      cameraController.dispose();
    } on CameraException catch (e) {
      _showErrorSnackBar(e.message ?? '');
    } catch (e) {
      log(e.toString());
    }
  }

  void setFlash(FlashState type) async {
    try {
      await cameraController.setFlash(type);
    } on CameraException catch (e) {
      _showErrorSnackBar(e.message ?? '');
    } catch (e) {
      log(e.toString());
    }
  }

  void switchCamera(CameraType type) async {
    try {
      await cameraController.switchCameraLens(type);
      setState(() {
        _lensType = type;
      });
    } on CameraException catch (e) {
      _showErrorSnackBar(e.message ?? '');
    } catch (e) {
      log(e.toString());
    }
  }

  void takePicture() async {
    try {
      final image = await cameraController.takePicture();

      var testImage = await image.readAsBytes();
      var uuid = Uuid();

      final result = await ImageGallerySaver.saveImage(testImage,
          quality: 100, name: "hello" + uuid.v4());

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Success Take Picture: ${image.path}'),
        backgroundColor: Colors.green,
      ));
    } on CameraException catch (e) {
      _showErrorSnackBar(e.message ?? '');
      log(e.toString());
    }
  }

  void setZoomRatio(double zoomRatio) async {
    try {
      await cameraController.setZoomRatio(zoomRatio);
    } on CameraException catch (e) {
      _showErrorSnackBar(e.message ?? '');
    } catch (e) {
      log(e.toString());
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }
}
