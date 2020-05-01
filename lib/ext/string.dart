import 'dart:core';
import 'dart:io';
import 'package:path/path.dart' as Path;

extension StringExt on String {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static Map<String, String> ENVIRONMENT;

  static final bool IS_WINDOWS = Platform.isWindows;

  static final RegExp BLANK = RegExp(r'^[\s]*$');

  static const String EMPTY = '';
  static const int EOT_CODE = 4;
  static final String EOT = String.fromCharCode(StringExt.EOT_CODE);
  static const String FALSE_STR = 'false';
  static const String NEWLINE = '\n';
  static const String SPACE = ' ';
  static const String TAB = '\t';
  static const String TRUE = 'true';
  static const String FALSE = 'false';

  static const String STDIN_DISP = '<stdin>';
  static const String STDIN_PATH = '-';

  static const String STDOUT_DISP = '<stdout>';
  static const String STDOUT_PATH = StringExt.STDIN_PATH;

  static final RegExp RE_ENV_NAME = RegExp(r'\$[\{]?([A-Z_][A-Z _0-9]*)[\}]?', caseSensitive: false);
  static final RegExp RE_PATH_SEP = RegExp(r'[\/\\]', caseSensitive: false);
  static final RegExp RE_PROTOCOL = RegExp(r'^[a-z]+[\:][\/][\/]+', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  String adjustPath() {
    var adjustedPath = trim().replaceAll(RE_PATH_SEP, Platform.pathSeparator);

    return adjustedPath;
  }

  //////////////////////////////////////////////////////////////////////////////

  String expandEnvironmentVariables() {
    if (ENVIRONMENT == null) {
      _initEnvironmentVariables();
    }

    var result =
      replaceAll('\$\$', '\x01').
      replaceAllMapped(RE_ENV_NAME, (match) {
        var envName = match.group(1);

        if (IS_WINDOWS) {
          envName = envName.toUpperCase();
        }

        if (ENVIRONMENT.containsKey(envName)) {
          return ENVIRONMENT[envName];
        }
        else {
          return EMPTY;
        }
      }).
      replaceAll('\x01', '\$');

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getFullPath() {
    var fullPath = (this == STDIN_PATH ? this : Path.canonicalize(adjustPath()));

    return fullPath;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void _initEnvironmentVariables() {
    ENVIRONMENT = {};

    if (IS_WINDOWS) {
      Platform.environment.forEach((k, v) {
        ENVIRONMENT[k.toUpperCase()] = v;
      });
    }
    else {
      ENVIRONMENT = Map.from(Platform.environment);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isNullOrBlank(String input) {
    return ((input == null) || BLANK.hasMatch(input));
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isNullOrEmpty(String input) {
    return ((input == null) || input.isEmpty);
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool parseBool(String input) {
    return ((input != null) && (input.toLowerCase() == TRUE));
  }

  //////////////////////////////////////////////////////////////////////////////
  // N.B. Single quotes are not supported by JSON standard, only double quotes
  //////////////////////////////////////////////////////////////////////////////

  String removeJsComments() {
    var jsCommentsRE = RegExp(r'(\"[^\"]*\")|\/\/[^\x01]*\x01|\/\*((?!\*\/).)*\*\/', multiLine: false);

    var result =
       replaceAll('\r\n', '\x01').
       replaceAll('\r',   '\x01').
       replaceAll('\n',   '\x01').
       replaceAll('\\\\', '\x02').
       replaceAll('\\\"', '\x03').
       replaceAllMapped(jsCommentsRE, (Match match) {
         var literalString = match.group(1);
         var isCommented = isNullOrBlank(literalString);

         return (isCommented ? EMPTY : literalString);
       }).
       replaceAll('\x03', '\\\"').
       replaceAll('\x02', '\\\\').
       replaceAll('\x01', '\n')
    ;

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////
}