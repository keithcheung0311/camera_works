import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'enum/enum.dart';
import 'params/camera_args.dart';
import 'util.dart';

/// A camera controller.
abstract class CameraController {
  /// Arguments for [CameraView].
  ValueNotifier<CameraArgs?> get args;

  /// Torch state of the camera.
  ValueNotifier<FlashState> get torchState;

  ValueNotifier<double> get zoomRatioNotifier;

  // final zoomRatioNotifier = ValueNotifier<double>(1.0);
  // set _zoomRatio(double value) => zoomRatioNotifier.value = value;

  /// Create a [CameraController].
  ///
  /// [facing] target facing used to select camera.
  ///
  /// [formats] the barcode formats for image analyzer.
  factory CameraController(CameraType facing) => _CameraController(facing);

  /// Start the camera asynchronously.
  Future<void> startAsync();

  /// Switch the torch's state.
  Future<void> setFlash(FlashState state);

  /// Get status has Front Camera in Device
  Future<bool> hasFrontCamera();

  /// Get status has Back Camera in Device
  Future<bool> hasBackCamera();

  /// Switch the camera type front or back
  Future<void> switchCameraLens(CameraType type);

  /// Take Picture, return File
  Future<File> takePicture();

  Future<void> setZoomRatio(double value);

  Future<void> setFocus(BoxConstraints boxConstraints, Offset offset);

  /// Release the resources of the camera.
  void dispose();
}

class _CameraController implements CameraController {
  static const MethodChannel method =
      MethodChannel('space.wisnuwiry/camera_works/method');
  static const EventChannel event =
      EventChannel('space.wisnuwiry/camera_works/event');

  static const undetermined = 0;
  static const authorized = 1;
  static const denied = 2;

  static int? id;
  static StreamSubscription? subscription;

  final CameraType facing;

  @override
  final ValueNotifier<CameraArgs?> args;

  @override
  final ValueNotifier<FlashState> torchState;

  @override
  final ValueNotifier<double> zoomRatioNotifier;

  bool torchable;

  _CameraController(this.facing)
      : args = ValueNotifier(null),
        torchState = ValueNotifier(FlashState.off),
        zoomRatioNotifier = ValueNotifier(1.0),
        torchable = false {
    // In case new instance before dispose.
    if (id != null) {
      stop();
    }
    id = hashCode;

    // Listen event handler.
    subscription =
        event.receiveBroadcastStream().listen((data) => handleEvent(data));
  }

  void handleEvent(Map<dynamic, dynamic> event) {
    final name = event['name'];
    final data = event['data'];
    switch (name) {
      case 'flashState':
        if (data != null) {
          final state = FlashState.values[data];
          torchState.value = state;
        }
        break;
      default:
        throw UnimplementedError();
    }
  }

  @override
  Future<void> startAsync() async {
    try {
      ensure('startAsync');
      // Check authorization state.
      var state = await method.invokeMethod('state');
      if (state == undetermined) {
        final result = await method.invokeMethod('requestPermission');
        state = result ? authorized : denied;
      }
      if (state != authorized) {
        throw PlatformException(code: 'NO ACCESS');
      }
      print(facing.index);
      // Start camera.
      final answer =
          await method.invokeMapMethod<String, dynamic>('start', facing.index);
      final textureId = answer?['textureId'];
      final size = toSize(answer?['size']);
      args.value = CameraArgs(textureId, size);
      torchable = answer?['hasFlash'];
    } on PlatformException catch (e) {
      throw e.toCameraException();
    }
  }

  @override
  Future setFlash(FlashState state) async {
    try {
      ensure('setFlash');
      if (!torchable) {
        return;
      }

      await method.invokeMethod('setFlash', state.index);
    } on PlatformException catch (e) {
      throw e.toCameraException();
    }
  }

  @override
  void dispose() {
    try {
      if (hashCode == id) {
        stop();
        subscription?.cancel();
        subscription = null;
        id = null;
      }
    } on PlatformException catch (e) {
      throw e.toCameraException();
    }
  }

  void stop() {
    try {
      method.invokeMethod('stop');
    } on PlatformException catch (e) {
      throw e.toCameraException();
    }
  }

  void ensure(String name) {
    final message =
        'CameraController.$name called after CameraController.dispose\n'
        'CameraController methods should not be used after calling dispose.';
    assert(hashCode == id, message);
  }

  @override
  Future<bool> hasBackCamera() async {
    try {
      return await method.invokeMethod('hasBackCamera');
    } on PlatformException catch (e) {
      throw e.toCameraException();
    }
  }

  @override
  Future<bool> hasFrontCamera() async {
    try {
      return await method.invokeMethod('hasFrontCamera');
    } on PlatformException catch (e) {
      throw e.toCameraException();
    }
  }

  @override
  Future<void> switchCameraLens(CameraType type) async {
    try {
      if (type == CameraType.front) {
        await method.invokeMethod('switchCamera', type.index);
        await setFlash(FlashState.off);
      } else {
        await method.invokeMethod('switchCamera', type.index);
      }
    } on PlatformException catch (e) {
      throw e.toCameraException();
    }
  }

  @override
  Future<File> takePicture() async {
    try {
      final path = await method.invokeMethod('takePicture');

      return File(path);
    } on PlatformException catch (e) {
      throw e.toCameraException();
    }
  }

  @override
  Future<void> setZoomRatio(double zoomRatio) async {
    try {
        zoomRatioNotifier.value = zoomRatio;
        await method.invokeMethod('setZoomRatio', zoomRatio);
    } on PlatformException catch (e) {
      throw e.toCameraException();
    }
  }

  @override
  Future<void> setFocus(BoxConstraints boxConstraints, Offset offset) async {
    try {
      print("CameraPicker - boxConstraints maxHeight" + boxConstraints.maxHeight.toString());
      print("CameraPicker - boxConstraints maxWidth" + boxConstraints.maxWidth.toString());
      print("CameraPicker - offset dx" + offset.dx.toString());
      print("CameraPicker - offset dy" + offset.dy.toString());
      final Map<String, double> data = {
        "height": boxConstraints.maxHeight,
        "width": boxConstraints.maxWidth,
        "x": offset.dx,
        "y": offset.dy,
      };
      await method.invokeMethod<Map<String, double>>('setFocus', json.encode(data));
    } on PlatformException catch (e) {
      throw e.toCameraException();
    }
  }
}
