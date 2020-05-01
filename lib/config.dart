import 'package:path/path.dart' as Path;
import 'app_file_loader.dart';
import 'log.dart';
import 'options.dart';
import 'ext/string.dart';

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final String CFG_ACTION = 'action';
  static final String CFG_RENAME = 'rename';

  static final String CMD_EXPAND = 'expand-only';

  //static final int MAX_EXPANSION_ITERATIONS = 10;

  static final RegExp RE_PARAM_NAME = RegExp(r'[\{][^\{\}]+[\}]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  int lastModifiedMcsec;

  String paramNameCmd = '{{-cmd-}}';
  String paramNameCurDir = '{{-cur-dir-}}';
  String paramNameExpInp = '{{-exp-inp-}}';
  String paramNameInp = '{{-inp-}}';
  String paramNameInpDir = '{{-inp-dir-}}';
  String paramNameInpExt = '{{-inp-ext-}}';
  String paramNameInpName = '{{-inp-name-}}';
  String paramNameInpNameExt = '{{-inp-name-ext-}}';
  String paramNameInpPath = '{{-inp-path-}}';
  String paramNameInpSubDir = '{{-inp-sub-dir-}}';
  String paramNameInpSubPath = '{{-inp-sub-path-}}';
  String paramNameImport = '{{-import-}}';
  String paramNameOut = '{{-out-}}';

  //////////////////////////////////////////////////////////////////////////////

  void addFlatMapsToList(List<Map<String, String>> listOfMaps, Map<String, Object> map) {
    var cloneMap = <String, Object>{};
    cloneMap.addAll(map);

    var isMapFlat = true;

    map.forEach((k, v) {
      if ((v == null) || !isMapFlat /* only one List or Map per call */) {
        return;
      }

      if (v is List) {
        isMapFlat = false;
        addFlatMapsToList_addList(listOfMaps, cloneMap, k, v);
      }
      else if (v is Map) {
        isMapFlat = false;
        addFlatMapsToList_addMap(listOfMaps, cloneMap, k, v);
      }
      else {
        cloneMap[k] = v;
      }
    });

    if (isMapFlat) {
      var strStrMap = <String, String>{};

      cloneMap.forEach((k, v) {
        strStrMap[k] = v.toString();
      });

      listOfMaps.add(strStrMap);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void addFlatMapsToList_addList(List<Map<String, String>> listOfMaps, Map<String, Object> map, String key, List<Object> argList) {
    var cloneMap = <String, Object>{};
    cloneMap.addAll(map);

    for (var i = 0, n = argList.length; i < n; i++) {
      cloneMap[key] = argList[i];
      addFlatMapsToList(listOfMaps, cloneMap);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void addFlatMapsToList_addMap(List<Map<String, String>> listOfMaps, Map<String, Object> map, String key, Map<String, Object> argMap) {
    var cloneMap = <String, Object>{};

    cloneMap.addAll(map);
    cloneMap.remove(key);
    cloneMap.addAll(argMap);

    addFlatMapsToList(listOfMaps, cloneMap);
  }

  //////////////////////////////////////////////////////////////////////////////

  void addMapsToList(List<Map<String, String>> listOfMaps, Map<String, Object> map) {
    var isReady = ((map != null) && deepContainsKeys(map, [paramNameInp, paramNameOut]));

    if (isReady) {
      addFlatMapsToList(listOfMaps, map);
      map.remove(paramNameOut);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  bool deepContainsKeys(Map<String, Object> map, List<String> keys, {Map<String, bool> isFound}) {
    if ((map == null) || (keys == null)) {
      return false;
    }

    var isFoundAll = false;

    if (isFound == null) {
      isFound = {};

      for (var i = 0, n = keys.length; i < n; i++) {
        isFound[keys[i]] = false;
      }
    }

    map.forEach((k, v) {
      if (!isFoundAll) {
        if (keys.contains(k)) {
          isFound[k] = true;
        }
        else if (v is List) {
          for (var i = 0, n = v.length; i < n; i++) {
            var vv = v[i];

            if (vv is Map) {
              isFoundAll = deepContainsKeys(vv, keys, isFound: isFound);
            }
          }
        }
        else if (v is Map) {
          isFoundAll = deepContainsKeys(v, keys, isFound: isFound);
        }
      }
    });

    isFoundAll = !isFound.containsValue(false);

    return isFoundAll;
  }

  //////////////////////////////////////////////////////////////////////////////

  List<Object> injectPlainArgs(List<Object> actions) {
    var args = Options.plainArgs;
    var argCount = (args?.length ?? 0);

    if (argCount > 0) {
      var obj = (argCount == 1 ? args[0] : args);

      actions.insert(0, <String, Object>{AppFileLoader.ALL_ARGS: obj});
    }

    return actions;
  }

  //////////////////////////////////////////////////////////////////////////////

  List<Map<String, String>> exec(List<String> args) {
    Options.parseArgs(args);

    Log.information('Loading configuration data');

    var all = loadConfigSync();

    Log.information('Processing configuration data');

    if (all is Map) {
      var rename = all[CFG_RENAME];

      Log.information('Processing renames');

      if (rename is Map) {
        setActualParamNames(rename);
      }

      Log.information('Processing actions');

      var params = <String, Object>{};
      params[paramNameCurDir] = '';

      var action = all[CFG_ACTION];
      assert(action is List);

      var actions = (action as List);
      injectPlainArgs(actions);

      var result = <Map<String, String>>[];

      actions.forEach((map) {
        assert(map is Map);

        Log.debug('');

        map.forEach((key, value) {
          if (!StringExt.isNullOrBlank(key)) {
            Log.debug('...${key}: ${value}');

            params[key] = (value ?? StringExt.EMPTY);
          }
        });

        if (params.isNotEmpty) {
          Log.debug('...adding to the list of actions');

          addMapsToList(result, params);
        }

        Log.debug('...completed row processing');
      });

      Log.information('\nAdded ${result.length} commands\n');

      return result;
    }
    else {
      Log.information('No command added');

      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String getFullCurDirName(String curDirName) {
    return Path.join(Options.startDirName, curDirName).getFullPath();
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isParamWithPath(String paramName) {
    return (
        (paramName == paramNameCurDir) ||
        (paramName == paramNameInp) ||
        (paramName == paramNameOut)
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  Map<String, Object> loadConfigSync() {
    var lf = AppFileLoader().loadJsonSync(Options.configFilePath, paramNameImport: paramNameImport);

    lastModifiedMcsec = lf.lastModifiedMcsec;

    if (lf.data is Map) {
      return (lf.data as Map).values.toList()[0];
    }
    else {
      return lf.data;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void setActualParamNames(Map<String, Object> renames) {
    renames.forEach((k, v) {
      if (k == paramNameCmd) {
        paramNameCmd = v;
      }
      else if (k == paramNameCurDir) {
        paramNameCurDir = v;
      }
      else if (k == paramNameExpInp) {
        paramNameExpInp = v;
      }
      else if (k == paramNameInp) {
        paramNameInp = v;
      }
      else if (k == paramNameInpDir) {
        paramNameInpDir = v;
      }
      else if (k == paramNameInpExt) {
        paramNameInpExt = v;
      }
      else if (k == paramNameInpName) {
        paramNameInpName = v;
      }
      else if (k == paramNameInpNameExt) {
        paramNameInpNameExt = v;
      }
      else if (k == paramNameInpPath) {
        paramNameInpPath = v;
      }
      else if (k == paramNameInpSubDir) {
        paramNameInpSubDir = v;
      }
      else if (k == paramNameInpSubPath) {
        paramNameInpSubPath = v;
      }
      else if (k == paramNameImport) {
        paramNameImport = v;
      }
      else if (k == paramNameOut) {
        paramNameOut = v;
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////

}
