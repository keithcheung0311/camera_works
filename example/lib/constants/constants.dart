import 'dart:developer';

import 'package:flutter/foundation.dart';

/// Log only in debug mode.
/// 只在调试模式打印
void realDebugPrint(dynamic message) {
  if (!kReleaseMode) {
    log('$message', name: 'CameraPicker - LOG');
  }
}

int get currentTimeStamp => DateTime.now().millisecondsSinceEpoch;
