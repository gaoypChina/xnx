import 'dart:io';

import 'package:doul/src/ext/string.dart';

class Logger {
  static const String STUB_LEVEL = '{L}';
  static const String STUB_MESSAGE = '{M}';
  static const String STUB_TIME = '{T}';

  static const String FORMAT_DEFAULT = null;
  static const String FORMAT_SIMPLE = '[$STUB_TIME] [$STUB_LEVEL] $STUB_MESSAGE';

  static const int LEVEL_SILENT = 0;
  static const int LEVEL_ERROR = 1;
  static const int LEVEL_OUT = 2;
  static const int LEVEL_WARNING = 3;
  static const int LEVEL_INFORMATION = 4;
  static const int LEVEL_DEBUG = 5;

  static const int LEVEL_DEFAULT = LEVEL_OUT;

  static const LEVELS = [ 'quiet', 'errors', 'normal', 'warnings', 'info', 'debug' ];

  static final RegExp RE_PREFIX = RegExp(r'^', multiLine: true);

  String _format = FORMAT_DEFAULT;
  String get format => _format;
  set format(String value) => _format = (StringExt.isNullOrEmpty(value) ? null : value);

  int _level = LEVEL_DEFAULT;
  int get level => _level;

  set level(int value) =>
    _level = value < 0 ? LEVEL_DEFAULT :
             value >= LEVEL_DEBUG ? LEVEL_DEBUG : value;

  set levelAsString(String value) {
    if (StringExt.isNullOrBlank(value)) {
      _level = LEVEL_DEFAULT;
    }
    else {
      _level = LEVELS.indexOf(value);

      if (_level < 0) {
        _level = int.tryParse(value) ?? LEVEL_DEFAULT;
      }
    }
  }

  void debug(String data) {
    print(data, LEVEL_DEBUG);
  }

  void error(String data) {
    print(data, LEVEL_ERROR);
  }

  String formatMessage(String msg) {
    if (msg == null) {
      return msg;
    }

    var now = DateTime.now().toString();
    var lvl = levelToString(level);
    var pfx = (StringExt.isNullOrEmpty(_format) ? StringExt.EMPTY : _format.replaceFirst(STUB_TIME, now).replaceFirst(STUB_LEVEL, lvl).replaceFirst(STUB_MESSAGE, msg));

    var msgEx = msg.replaceAll(RE_PREFIX, pfx);

    return msgEx;
  }

  bool hasMinLevel(int minLevel) => (_level >= minLevel);

  bool get hasLevel => (_level != LEVEL_DEFAULT);

  bool get isDefault => (_level == LEVEL_DEFAULT);

  bool get isDetailed => (_level >= LEVEL_INFORMATION);

  bool get isSilent => (_level == LEVEL_SILENT);

  bool get isUltimate => (_level >= LEVEL_DEBUG);

  bool get isUnknown => !hasLevel;

  void information(String data) {
    print(data, LEVEL_INFORMATION);
  }

  static String levelToString(int level) {
    switch (level) {
      case LEVEL_DEBUG: return 'DBG';
      case LEVEL_ERROR: return 'ERR';
      case LEVEL_INFORMATION: return 'INF';
      case LEVEL_WARNING: return 'WRN';
      default: return StringExt.EMPTY;
    }
  }

  void out(String data) {
    print(data, LEVEL_OUT);
  }

  void print(String msg, int level) {
    if ((level > _level) || (msg == null)) {
      return;
    }

    if (level == LEVEL_OUT) {
      stdout.writeln(msg);
    }
    else {
      stderr.writeln(_format == null ? msg : formatMessage(msg));
    }
  }

  void warning(String data) {
    print(data, LEVEL_WARNING);
  }
}