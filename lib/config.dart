import 'dart:convert';
import 'dart:io';

import 'ext/string.dart';
import 'options.dart';

class Config {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final String CFG_ACTION = 'action';
  static final String CFG_RENAME = 'rename';

  static final String CMD_EXPAND = 'expand-only';

  static final int MAX_EXPANSION_ITERATIONS = 10;

  static String PARAM_NAME_COMMAND = '{command}';
  static String PARAM_NAME_HEIGHT = '{height}';
  static String PARAM_NAME_INPUT = '{input}';
  static String PARAM_NAME_OUTPUT = '{output}';
  static String PARAM_NAME_EXPAND_ENV = '{expand-environment}';
  static String PARAM_NAME_EXPAND_INP = '{expand-input}';
  static String PARAM_NAME_TOPDIR = '{topDir}';
  static String PARAM_NAME_WIDTH = '{width}';

  static final RegExp RE_PARAM_NAME = RegExp('[\\{][^\\{\\}]+[\\}]', caseSensitive: false);
  static final RegExp RE_PATH_DONE = RegExp('^[\\/]|[\\:]', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  static Map<String, String> params;

  //////////////////////////////////////////////////////////////////////////////

  static void addParamValue(String key, Object value) {
    if (StringExt.isNullOrEmpty(key)) {
      return;
    }

    var strValue = StringExt.EMPTY;

    if (value != null) {
      assert(!(value is List));
      assert(!(value is Map));

      strValue = value.toString().trim();
    }

    params[key] = strValue;
  }

  //////////////////////////////////////////////////////////////////////////////

  static Future<List<Map<String, String>>> exec(List<String> args) async {
    Options.parseArgs(args);

    var text = await read();
    var decoded = jsonDecode(text);
    assert(decoded is Map);

    var all = decoded.values.toList()[0];

    if (all is Map) {
      var rename = all[CFG_RENAME];

      if (rename is Map) {
        setActualParamNames(rename);
      }

      params = Map();
      params[PARAM_NAME_TOPDIR] = '';

      var action = all[CFG_ACTION];
      assert(action is List);

      var result = List<Map<String, String>>();

      action.forEach((map) {
        assert(map is Map);

        map.forEach((key, value) {
          addParamValue(key, value);
        });

        expandParamValuesAndAddToList(result);
      });

      return result;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String expandParamValue(String paramName, {bool isForAny = false}) {

    var canExpandEnv = (params.containsKey(PARAM_NAME_EXPAND_ENV) ? StringExt.parseBool(params[PARAM_NAME_EXPAND_ENV]) : false);
    var paramValue = (params[paramName] ?? StringExt.EMPTY);

    if (canExpandEnv) {
      paramValue = StringExt.expandEnvironmentVariables(paramValue);
    }

    for (var i = 0; ((i < MAX_EXPANSION_ITERATIONS) && RE_PARAM_NAME.hasMatch(paramValue)); i++) {
      params.forEach((k, v) {
        if ((k != paramName) && (isForAny || (k != PARAM_NAME_COMMAND))) {
          if ((paramName != PARAM_NAME_COMMAND) || (k != PARAM_NAME_INPUT)) {
            paramValue = paramValue.replaceAll(k, v);
          }
        }
      });
    }

    if (isParamWithPath(paramName)) {
      paramValue = StringExt.getFullPath(paramValue);
    }

    return paramValue;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void expandParamValuesAndAddToList(List<Map<String, String>> lst) {
    if (!hasMinKnownParams()) {
      return;
    }
    
    var newParams = Map<String, String>();

    params.forEach((k, v) {
      if (k != PARAM_NAME_COMMAND) {
        newParams[k] = expandParamValue(k, isForAny: false);
      }
    });

    params.addAll(newParams);

    var command = expandParamValue(PARAM_NAME_COMMAND, isForAny: true);

    if (StringExt.isNullOrBlank(command)) {
      throw new Exception('Command is not defined for the output file "${params[PARAM_NAME_OUTPUT]}". Did you miss { "${PARAM_NAME_COMMAND}": "${CMD_EXPAND}" }?');
    }

    newParams[PARAM_NAME_COMMAND] = command;

    lst.add(newParams);

    removeMinKnownParams();
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool hasMinKnownParams() {
    var hasInput = params.containsKey(PARAM_NAME_INPUT);
    var hasOutput = params.containsKey(PARAM_NAME_OUTPUT);

    return (hasInput && hasOutput);
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isParamWithPath(String paramName) {
    return (
        (paramName == PARAM_NAME_INPUT) ||
        (paramName == PARAM_NAME_OUTPUT)
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getParamValue(Map<String, String> map, String paramName) {
    if (map.containsKey(paramName)) {
      return map[paramName];
    }
    else {
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Future<String> read() async {
    String text;

    if (Options.configFilePath == Options.PATH_STDIN) {
      text = readInputSync();
    }
    else {
      var file = new File(Options.configFilePath);

      if (!(await file.exists())) {
        throw new Exception('Failed to find expected configuration file: "${Options.configFilePath}"');
      }

      text = await file.readAsString();
    }

    return text;
  }

  static String readInputSync() {
    final List<int> input = [];

    for (var isEmpty = true; ; isEmpty = false) {
      var byte = stdin.readByteSync();

      if (byte < 0) {
        if (isEmpty) {
          return null;
        }

        break;
      }
      input.add(byte);
    }

    return utf8.decode(input, allowMalformed: true);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void removeMinKnownParams() {
    params.removeWhere((k, v) => (
      (k == PARAM_NAME_WIDTH) ||
      (k == PARAM_NAME_HEIGHT) ||
      (k == PARAM_NAME_OUTPUT)
    ));
  }

  //////////////////////////////////////////////////////////////////////////////

  static void setActualParamNames(Map<String, Object> renames) {
    renames.forEach((k, v) {
      if (k == PARAM_NAME_COMMAND) {
        PARAM_NAME_COMMAND = v;
      }
      else if (k == PARAM_NAME_HEIGHT) {
        PARAM_NAME_HEIGHT = v;
      }
      else if (k == PARAM_NAME_INPUT) {
        PARAM_NAME_INPUT = v;
      }
      else if (k == PARAM_NAME_OUTPUT) {
        PARAM_NAME_OUTPUT = v;
      }
      else if (k == PARAM_NAME_EXPAND_ENV) {
        PARAM_NAME_EXPAND_ENV = v;
      }
      else if (k == PARAM_NAME_EXPAND_INP) {
        PARAM_NAME_EXPAND_INP = v;
      }
      else if (k == PARAM_NAME_TOPDIR) {
        PARAM_NAME_TOPDIR = v;
      }
      else if (k == PARAM_NAME_WIDTH) {
        PARAM_NAME_WIDTH = v;
      }
    });
  }

  //////////////////////////////////////////////////////////////////////////////

}
