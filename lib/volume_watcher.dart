import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

enum AudioManager {
  /// Controls the Voice Call volume
  STREAM_VOICE_CALL,

  /// Controls the system volume
  STREAM_SYSTEM,

  /// Controls the ringer volume
  STREAM_RING,

  /// Controls the media volume
  STREAM_MUSIC,

  // Controls the alarm volume
  STREAM_ALARM,

  /// Controls the notification volume
  STREAM_NOTIFICATION,
}

class VolumeWatcher extends StatefulWidget {
  final Function(double) onVolumeChangeListener;
  final Widget child;

  VolumeWatcher({
    Key key,
    @required this.onVolumeChangeListener,
    this.child,
  }) : super(key: key) {
    assert(this.onVolumeChangeListener != null);
  }

  static const MethodChannel methodChannel =
      const MethodChannel('volume_watcher_method');
  static const EventChannel eventChannel =
      const EventChannel('volume_watcher_event');
  static StreamSubscription _subscription;
  static Map<int, Function> _events = {};
  static AudioManager _audioManager;

  /*
   * event channel回调
   */
  static void _onEvent(Object event) {
    _events.values.forEach((item) {
      if (item != null) {
        item(event);
      }
    });
  }

  /*
   * event channel回调失败
   */
  static void _onError(Object error) {
    print('Volume status: unknown.' + error.toString());
  }

  /// 添加监听器
  /// 返回id, 用于删除监听器使用
  static int addListener(Function onEvent) {
    if (_subscription == null) {
      //event channel 注册
      _subscription = eventChannel
          .receiveBroadcastStream('init')
          .listen(_onEvent, onError: _onError);
    }

    if (onEvent != null) {
      _events[onEvent.hashCode] = onEvent;
      getCurrentVolume(_audioManager).then((value) {
        onEvent(value);
      });
      return onEvent.hashCode;
    }
    return null;
  }

  /// 删除监听器
  static void removeListener(int id) {
    if (id != null) {
      _events.remove(id);
    }
  }

  @override
  State<StatefulWidget> createState() {
    return VolumeState();
  }

  static Future<String> get platformVersion async {
    final String version =
        await methodChannel.invokeMethod('getPlatformVersion');
    return version;
  }

  /*
   * 获取当前系统最大音量
   */
  static Future<double> getMaxVolume(AudioManager audioManager) async {
    _audioManager = audioManager;
    Map<String, int> map = <String, int>{};
    map.putIfAbsent("streamType", () {
      return _getInt(audioManager);
    });
    final double maxVolume =
        await methodChannel.invokeMethod('getMaxVolume', map);
    return maxVolume;
  }

  /*
   * 获取当前系统音量
   */
  static Future<double> getCurrentVolume(AudioManager audioManager) async {
    _audioManager = audioManager;
    Map<String, int> map = <String, int>{};
    map.putIfAbsent("streamType", () {
      return _getInt(audioManager);
    });
    final double currentVolume =
        await methodChannel.invokeMethod('getCurrentVolume', map);
    return currentVolume;
  }

  /*
   * 设置系统音量
   */
  static Future<bool> setVolume(
      AudioManager audioManager, double volume) async {
    _audioManager = audioManager;
    final bool success = await methodChannel.invokeMethod(
        'setVolume', {'streamType': _getInt(audioManager), 'volume': volume});
    return success;
  }

  /// 隐藏音量面板
  /// 仅ios有效
  static set hideVolumeView(bool value) {
    if (!Platform.isIOS) return;
    if (value == true) {
      methodChannel.invokeMethod('hideUI');
    } else {
      methodChannel.invokeMethod('showUI');
    }
  }
}

class VolumeState extends State<VolumeWatcher> {
  int _listenerId;

  @override
  void initState() {
    super.initState();
    _listenerId = VolumeWatcher.addListener(widget.onVolumeChangeListener);
  }

  @override
  void dispose() {
    VolumeWatcher.removeListener(_listenerId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? SizedBox();
  }
}

int _getInt(AudioManager audioManager) {
  switch (audioManager) {
    case AudioManager.STREAM_VOICE_CALL:
      return 0;
    case AudioManager.STREAM_SYSTEM:
      return 1;
    case AudioManager.STREAM_RING:
      return 2;
    case AudioManager.STREAM_MUSIC:
      return 3;
    case AudioManager.STREAM_ALARM:
      return 4;
    case AudioManager.STREAM_NOTIFICATION:
      return 5;
    default:
      return null;
  }
}
