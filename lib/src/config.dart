import 'package:xnx/src/config_key_data.dart';
import 'package:xnx/src/config_result.dart';
import 'package:xnx/src/config_file_loader.dart';
import 'package:xnx/src/expression.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/keywords.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/options.dart';

////////////////////////////////////////////////////////////////////////////////

typedef ConfigFlatMapProc = ConfigResult Function(FlatMap map);

////////////////////////////////////////////////////////////////////////////////

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String LIST_SEPARATOR = '\x01';
  static final RegExp RE_PARAM_NAME = RegExp(r'[\{][^\{\}]+[\}]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  Map all = {};
  RegExp? detectPathsRE;
  Expression? expression;
  FlatMap flatMap = FlatMap();
  Keywords kw = Keywords();
  int lastModifiedStamp = 0;
  Options options = Options();
  String prevFlatMapStr = '';
  Object? topData;

  final Map<Object, ConfigKeyData> _trail = {};
  Logger _logger = Logger();

  //////////////////////////////////////////////////////////////////////////////

  Config([Logger? log]) {
    if (log != null) {
      _logger = log;
    }

    options = Options(_logger);
  }

  //////////////////////////////////////////////////////////////////////////////

  bool canRun() {
    if (flatMap.isEmpty) {
      return false;
    }

    if (!(flatMap[kw.forRun]?.isBlank() ?? true)) {
      return true;
    }

    if (!(flatMap[kw.forCmd]?.isBlank() ?? true)) {
      if (flatMap.containsKey(kw.forInp)) {
        if (flatMap.containsKey(kw.forOut)) {
          return true;
        }
      }
    }

    return false;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult defaultExecFlatMap(Map<String, String> map) {
    if (_logger.isDebug) {
      _logger.debug('$map\n');
    }
    else {
      _logger.outInfo(map.containsKey(kw.forRun) ?
        'Run: ${expandStraight(map, map[kw.forRun] ?? '')}\n' :
        'Inp: ${expandStraight(map, map[kw.forInp] ?? '')}\n'
        'Out: ${expandStraight(map, map[kw.forOut] ?? '')}\n'
        'Cmd: ${expandStraight(map, map[kw.forCmd] ?? '')}\n'
      );
    }

    return ConfigResult.ok;
  }
  //////////////////////////////////////////////////////////////////////////////

  bool exec({List<String>? args, ConfigFlatMapProc? execFlatMap}) {
    _logger.information('Loading configuration data');

    var tmpAll = loadSync();

    if (tmpAll is Map) {
      all = tmpAll;
    }
    else {
      _logger.information('Nothing found');
      return false;
    }

    _logger.information('Processing configuration data');

    Map<String, Object>? renames;

    if (all.containsKey(kw.forRename)) {
      var map = all[kw.forRename];

      if (map is Map<String, Object>) {
        renames = {};
        renames.addAll(map);
        all.remove(kw.forRename);
      }
    }

    String? actionKey;

    if (all.length == 1) {
      actionKey = all.keys.first;
    }

    var actions = (actionKey == null ? all : all[actionKey]);

    _logger.information('Processing renames');
    kw.rename(renames);

    if (actions != null) {
      _logger.information('Processing actions');

      topData = actions;
      execData(null, topData, execFlatMap);
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execData(String? key, Object? data, ConfigFlatMapProc? execFlatMap) {
    if (data == null) {
      flatMap[key] = null;
      return (key == kw.forStop ? ConfigResult.stop : ConfigResult.ok);
    }

    var trailKeyData = _trail[data];

    if (trailKeyData != null) {
      return execData(trailKeyData.key, trailKeyData.data, execFlatMap);
    }

    if (data is List) {
      if (key == kw.forRun) { // direct execution in a loop
        return execDataListRun(key, data, execFlatMap);
      }
      else {
        return execDataList(key, data, execFlatMap);
      }
    }

    if (data is Map<String, Object>) {
      if (key == kw.forIf) {
        return execDataMapIf(data, execFlatMap);
      }
      else {
        return execDataMap(key, data, execFlatMap);
      }
    }

    return execDataPlain(key, data, execFlatMap);
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataList(String? key, List data, ConfigFlatMapProc? execFlatMap) {
    for (var childData in data) {
      if (childData == null) {
        continue;
      }

      setTrailFor(data, key, childData);
      var result = execData(null, topData, execFlatMap);

      if ((result != ConfigResult.ok) && (result != ConfigResult.okEndOfList)) {
        return result;
      }
    }

    setTrailFor(data, null, null);
    flatMap[key] = null;

    return ConfigResult.okEndOfList;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataListRun(String? key, List data, ConfigFlatMapProc? execFlatMap) {
    if (key == null) {
      return ConfigResult.stop;
    }

    var result = ConfigResult.ok;

    for (var childData in data) {
      if (childData == null) {
        continue;
      }

      flatMap[key] = childData.toString().trim();
      result = execDataRun(execFlatMap);

      if (result != ConfigResult.ok) {
        break;
      }
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataMap(String? key, Map<String, Object> data, ConfigFlatMapProc? execFlatMap) {
    var result = ConfigResult.ok;

    data.forEach((childKey, childData) {
      if (result == ConfigResult.ok) {
        result = execData(childKey, childData, execFlatMap);
      }
    });

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataMapIf(Map<String, Object> data, ConfigFlatMapProc? execFlatMap) {
    var result = ConfigResult.ok;

    var resolvedData = expression?.exec(data);

    if (resolvedData != null) {
      setTrailFor(data, kw.forThen, resolvedData);
      result = execData(kw.forThen, resolvedData, execFlatMap);
      setTrailFor(data, null, null);
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataPlain(String? key, Object data, ConfigFlatMapProc? execFlatMap) {
    if (key == null) {
      return ConfigResult.stop;
    }

    if (key == Env.escape) {
      Env.escape = key;
      return ConfigResult.ok;
    }

    var result = ConfigResult.ok;

    if ((data is num) && ((data % 1) == 0)) {
      flatMap[key] = data.toStringAsFixed(0);
      return result;
    }

    var dataStr = data.toString().trim();
    var isEmpty = dataStr.isEmpty;

    if (key == kw.forDetectPaths) {
      detectPathsRE = (isEmpty ? null : RegExp(dataStr));
      return result;
    }

    if (key == kw.forStop) {
      if (!isEmpty) {
        _logger.out(flatMap.expand(dataStr));
      }

      return ConfigResult.stop;
    }

    if (!isEmpty) {
      var isKeyForGlob = kw.allForGlob.contains(key);
      var isKeyForPath = kw.allForPath.contains(key);
      var isDetectPaths = (detectPathsRE?.hasMatch(key) ?? false);
      var hasPath = (isKeyForGlob || isKeyForPath || isDetectPaths);

      if (hasPath) {
        dataStr = Path.adjust(dataStr);
      }
    }

    var isCmd = (key == kw.forCmd);
    var isRun = (key == kw.forRun);

    if (isCmd || isRun) {
      flatMap[isCmd ? kw.forRun : kw.forCmd] = null;
    }

    flatMap[key] = dataStr;

    if (canRun()) {
      result = execDataRun(execFlatMap);
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataRun(ConfigFlatMapProc? execFlatMap) {
    var result = ConfigResult.ok;

    if (isNewFlatMap()) {
      pushExeToBottom();

      if (execFlatMap != null) {
        result = execFlatMap(flatMap);
      }

      flatMap[kw.forOut] = null;
      flatMap[kw.forRun] = null;
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  String expandStraight(Map<String, String> map, String value) {
    if (value.isEmpty || map.isEmpty) {
      return value;
    }

    for (var oldValue = ''; oldValue != value;) {
      oldValue = value;

      map.forEach((k, v) {
        if (value.contains(k)) {
          value = value.replaceAll(k, v.toString());
        }
      });
    }

    return value;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getFullCurDirName(String curDirName) {
    return Path.getFullPath(Path.join(options.startDirName, curDirName));
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isNewFlatMap() {
    var flatMapStr = sortAndEncodeFlatMap();
    var isNew = (flatMapStr != prevFlatMapStr);
    prevFlatMapStr = flatMapStr;

    if (_logger.isDebug) {
      _logger.debug('Is new map: $isNew');
    }

    return isNew;
  }

  //////////////////////////////////////////////////////////////////////////////

  Map<String, Object?> loadSync() {
    var lf = ConfigFileLoader(logger: _logger);
    lf.loadJsonSync(options.configFileInfo, paramNameImport: kw.forImport, appPlainArgs: options.plainArgs);

    lastModifiedStamp = lf.lastModifiedStamp ?? 0;

    var data = lf.data;

    if (data == null) {
      return {};
    }

    if (data is Map<String, Object?>) {
      return data;
    }
    else {
      return <String, Object?>{ '+': data};
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void print(String? msg, {bool isSilent = false}) {
    if (isSilent) {
      _logger.out(msg ?? '');
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void pushExeToBottom() {
    var key = kw.forRun;
    var exe = flatMap[key];

    if (exe == null) {
      key = kw.forCmd;
      exe = flatMap[key];
    }

    if (exe != null) {
      flatMap[key] = exe;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void setTrailFor(Object currData, String? toKey, Object? toData) {
    if (toKey == null) {
      _trail.remove(currData);
    }
    else {
      _trail[currData] = ConfigKeyData(toKey, toData);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String sortAndEncodeFlatMap() {
    var list = flatMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    var result = '{${list.map((x) =>
      '${x.key.quote()}:${x.value.quote()}'
    ).join(',')}';

    if (_logger.isDebug) {
      _logger.debug(result);
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

}
