import 'package:json5/json5.dart';
import 'package:meta/meta.dart';
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
import 'package:xnx/src/operation.dart';
import 'package:xnx/src/options.dart';
import 'package:xnx/src/functions.dart';
import 'package:xnx/src/path_filter.dart';

////////////////////////////////////////////////////////////////////////////////

typedef ConfigFlatMapProc = ConfigResult Function(FlatMap map);

////////////////////////////////////////////////////////////////////////////////

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  @protected late final Expression expression;
  @protected late final FlatMap flatMap;
  late final Keywords keywords;
  @protected late final Operation operation;
  @protected late final Functions functions;

  Map all = {};
  RegExp? detectPathsRE;
  PathFilter skip = PathFilter();
  PathFilter take = PathFilter();

  int lastModifiedStamp = 0;
  Options options = Options();
  String prevFlatMapStr = '';
  Object? topData;

  final List<Object> _once = [];
  final Map<Object, ConfigKeyData> _trail = {};
  Logger _logger = Logger();

  //////////////////////////////////////////////////////////////////////////////

  Config([Logger? log]) {
    if (log != null) {
      _logger = log;
    }

    options = Options(_logger);
    keywords = Keywords(options: options, logger: _logger);
    flatMap = FlatMap(keywords: keywords);
    operation = Operation(flatMap: flatMap, logger: _logger);
    expression = Expression(flatMap: flatMap, keywords: keywords, operation: operation, logger: _logger);
    functions = Functions(flatMap: flatMap, keywords: keywords, logger: _logger);
  }

  //////////////////////////////////////////////////////////////////////////////

  bool canRun() {
    if (flatMap.isEmpty) {
      return false;
    }

    if (!(flatMap[keywords.forRun]?.isBlank() ?? true)) {
      return true;
    }

    if (!(flatMap[keywords.forCmd]?.isBlank() ?? true)) {
      if (flatMap.containsKey(keywords.forInp)) {
        if (flatMap.containsKey(keywords.forOut)) {
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
      _logger.outInfo(map.containsKey(keywords.forRun) ?
        'Run: ${expandStraight(map, map[keywords.forRun] ?? '')}\n' :
        'Inp: ${expandStraight(map, map[keywords.forInp] ?? '')}\n'
        'Out: ${expandStraight(map, map[keywords.forOut] ?? '')}\n'
        'Cmd: ${expandStraight(map, map[keywords.forCmd] ?? '')}\n'
      );
    }

    return ConfigResult.ok;
  }
  //////////////////////////////////////////////////////////////////////////////

  bool exec({List<String>? args, ConfigFlatMapProc? execFlatMap}) {
    _logger.information('Loading actions');

    var all = loadSync();

    if (all.isEmpty) {
      _logger.information('Nothing found');
      return false;
    }
    else {
      loadAppConfig();
      
      _logger.information('Processing actions');

      topData = all;
      execData(null, topData, execFlatMap);

      return true;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execData(String? key, Object? data, ConfigFlatMapProc? execFlatMap) {
    if (data == null) {
      var keyEx = keywords.refine(key);
      flatMap[keyEx] = null;
      return (keyEx == keywords.forStop ? ConfigResult.stop : ConfigResult.ok);
    }

    if (_once.contains(data)) {
      return ConfigResult.ok;
    }

    var trailKeyData = _trail[data];

    if (trailKeyData != null) {
      return execData(trailKeyData.key, trailKeyData.data, execFlatMap);
    }

    if (data is List) {
      if (key?.startsWith(keywords.forRun) ?? false) { // direct execution in a loop
        return execDataListRun(key, data, execFlatMap);
      }
      else {
        return execDataList(key, data, execFlatMap);
      }
    }

    if (data is Map<String, Object?>) {
      if (key?.startsWith(keywords.forIf) ?? false) {
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
    var isCmd = false;

    if (key != null) {
      if (key.startsWith(keywords.forOnce)) {
        _once.add(data);
      }
      else if (key.startsWith(keywords.forFunc)) {
        functions.exec(data);
        return ConfigResult.ok;
      }

      isCmd = (key.startsWith(keywords.forCmd));
    }

    for (var childData in data) {
      if (childData == null) {
        continue;
      }

      setTrailFor(data, key, childData);
      var oldOut = (isCmd ? flatMap[keywords.forOut] : null);
      var result = execData(null, topData, execFlatMap);

      if (isCmd && (oldOut != null) && (flatMap[keywords.forOut] == null)) {
        flatMap[keywords.forOut] = oldOut;
      }

      if ((result != ConfigResult.ok) && (result != ConfigResult.okEndOfList)) {
        return result;
      }
    }

    setTrailFor(data, null, null);

    if (isCmd) {
      flatMap[keywords.forCmd] = null;
      flatMap[keywords.forOut] = null;
    }
    else {
      flatMap[keywords.refine(key)] = null;
    }

    return ConfigResult.okEndOfList;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataListRun(String? key, List data, ConfigFlatMapProc? execFlatMap) {
    if (key == null) {
      return ConfigResult.stop;
    }

    var keyEx = keywords.refine(key);
    var result = ConfigResult.ok;

    for (var childData in data) {
      if (childData == null) {
        continue;
      }

      flatMap[keyEx] = childData.toString().trim();
      result = execDataRun(execFlatMap);

      if (result != ConfigResult.ok) {
        break;
      }
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataMap(String? key, Map<String, Object?> data, ConfigFlatMapProc? execFlatMap) {
    var result = ConfigResult.ok;

    if (key != null) {
      if (key.startsWith(keywords.forOnce)) {
        _once.add(data);
      }
      else if (key.startsWith(keywords.forSkip)) {
        skip.init(isNot: (data['isNot'] as bool?), isPath: (data['isPath'] as bool?), mask: (data['mask'] as String?), regex: (data['regex'] as String?));
        return result;
      }
      else if (key.startsWith(keywords.forTake)) {
        take.init(isNot: (data['isNot'] as bool?), isPath: (data['isPath'] as bool?), mask: (data['mask'] as String?), regex: (data['regex'] as String?));
        return result;
      }
      else if (key.startsWith(keywords.forFunc)) {
        functions.exec(data);
        return result;
      }
    }

    data.forEach((childKey, childData) {
      if (result == ConfigResult.ok) {
        result = execData(childKey, childData, execFlatMap);
      }
    });

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataMapIf(Map<String, Object?> data, ConfigFlatMapProc? execFlatMap) {
    var result = ConfigResult.ok;

    var resolvedData = expression.exec(data);

    if (resolvedData != null) {
      var key = data.keys.first;
      setTrailFor(data, key, resolvedData);
      result = execData(key, resolvedData, execFlatMap);
      setTrailFor(data, null, null);
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  ConfigResult execDataPlain(String? key, Object data, ConfigFlatMapProc? execFlatMap) {
    if (key == null) {
      _logger.error('The key is null');
      return ConfigResult.stop;
    }

    if (key == Env.escape) {
      Env.escape = key;
      return ConfigResult.ok;
    }

    var keyEx = keywords.refine(key) ?? '';
    var result = ConfigResult.ok;

    if ((data is num) && ((data % 1) == 0)) {
      flatMap[keyEx] = data.toStringAsFixed(0);
      return result;
    }

    var dataStr = data.toString().trim();
    var isEmpty = dataStr.isEmpty;

    if (keyEx == keywords.forDetectPaths) {
      detectPathsRE = (isEmpty ? null : RegExp(dataStr));
      return result;
    }

    if (keyEx == keywords.forStop) {
      if (!isEmpty) {
        _logger.error(flatMap.expand(dataStr));
      }

      return ConfigResult.stop;
    }

    if (!isEmpty) {
      var isKeyForGlob = keywords.allForGlob.contains(keyEx);
      var isKeyForPath = keywords.allForPath.contains(keyEx);
      var isDetectPaths = (detectPathsRE?.hasMatch(keyEx) ?? false);
      var hasPath = (isKeyForGlob || isKeyForPath || isDetectPaths);

      if (hasPath) {
        dataStr = Path.adjust(dataStr);
      }
    }

    var isCmd = (keyEx == keywords.forCmd);
    var isRun = !isCmd && (keyEx == keywords.forRun);

    if (isCmd || isRun) {
      flatMap[isCmd ? keywords.forRun : keywords.forCmd] = null;
    }

    flatMap[keyEx] = dataStr;

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

      flatMap[keywords.forOut] = null;
      flatMap[keywords.forRun] = null;
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

  void loadAppConfig() {
    _logger.information('Loading the application configuration');

    if (options.appConfigPath.isNotEmpty) {
      var file = Path.fileSystem.file(options.appConfigPath);
      var text = file.readAsStringSync();
      var data = json5Decode(text);

      keywords.init(data);
      functions.init(data);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  Map<String, Object?> loadSync() {
    var lf = ConfigFileLoader(keywords: keywords, logger: _logger);
    lf.loadJsonSync(options.configFileInfo, appPlainArgs: options.plainArgs);

    lastModifiedStamp = lf.lastModifiedStamp;

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
    var key = keywords.forRun;
    var exe = flatMap[key];

    if (exe == null) {
      key = keywords.forCmd;
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
