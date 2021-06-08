import 'dart:cli';
import 'dart:convert';
import 'dart:io';

import 'package:doul/config_file_loader.dart';
import 'package:doul/config.dart';
import 'package:doul/doul.dart';
import 'package:doul/ext/glob.dart';
import 'package:doul/file_oper.dart';
import 'package:doul/logger.dart';
import 'package:doul/options.dart';
import 'package:doul/pack_oper.dart';
import 'package:doul/ext/directory.dart';
import 'package:doul/ext/file.dart';
import 'package:doul/ext/file_system_entity.dart';
import 'package:doul/ext/stdin.dart';
import 'package:doul/ext/string.dart';

import 'package:path/path.dart' as path;
import 'package:process_run/shell_run.dart';

class Convert {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const String FILE_TYPE_TMP = '.tmp';

  //////////////////////////////////////////////////////////////////////////////
  // Parameters
  //////////////////////////////////////////////////////////////////////////////

  bool canExpandContent;
  RegExp detectPathsRE;
  bool hasStop;
  bool isExpandContentOnly;
  bool isStdIn;
  bool isStdOut;
  String curDirName;
  String outDirName;
  String startCmd;

  Config _config;
  List<String> _inpParamNames;
  Logger _logger;
  Options _options;

  //////////////////////////////////////////////////////////////////////////////

  Convert(Logger log) {
    _logger = log;
  }

  //////////////////////////////////////////////////////////////////////////////

  void exec(List<String> args) {
    startCmd = FileExt.getStartCommand();

    _config = Config(_logger);
    var maps = _config.exec(args: args);
    _options = _config.options;
    PackOper.compression = _options.compression;
    var plainArgs = _options.plainArgs;

    var hasMaps = (maps?.any((x) => x.isNotEmpty) ?? false);

    if (!hasMaps && _options.isCmd) {
      execBuiltin(_options.plainArgs);
      return;
    }

    _inpParamNames = _config.getInpParamNames();

    for (; hasMaps; maps = _config.exec(), hasMaps = (maps?.any((x) => x.isNotEmpty) ?? false)) {
      if (_config.runNo > 1) {
        _logger.debug('\nRun #${_config.runNo} found\n');
      }

      var isProcessed = false;

      if ((plainArgs?.length ?? 0) <= 0) {
        plainArgs = [ null ];
      }

      hasStop = false;

      for (var i = 0, n = plainArgs.length; i < n; i++) {
        var mapPrev = <String, String>{};
        var plainArg = plainArgs[i];

        for (var mapOrig in maps) {
          if (execMap(plainArg, mapOrig, mapPrev)) {
            isProcessed = true;
          }
          if (hasStop) {
            return;
          }
        }
      }

      if ((isStdOut != null) && !isStdOut && !isProcessed) {
        _logger.outInfo('All output files are up to date.');
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void execBuiltin(List<String> args, {bool isSilent}) {
    var argCount = (args?.length ?? 0);

    isSilent ??= _logger.isSilent;

    if (argCount <= 0) {
      throw Exception('No argument specified for the built-in command');
    }

    var end = (args.length - 1);
    var arg1 = (end >= 0 ? args[0] : null);
    var arg2 = (end >= 1 ? args[1] : null);

    final isCompress = _options.isCmdCompress;
    final isDecompress = _options.isCmdDecompress;
    final isMove = _options.isCmdMove;

    if (isCompress || isDecompress) {
      final archPath = (isDecompress ? arg1 : (end >= 0 ? args[end] : 0));
      final archType = PackOper.getPackType(_options.archType, archPath);
      final isTar = PackOper.isPackTypeTar(archType);

      if (isTar || (archType == PackType.Zip)) {
        if (isCompress) {
          PackOper.archiveSync(fromPaths: args, end: end, packType: archType, isMove: isMove, isSilent: isSilent);
        }
        else {
          PackOper.unarchiveSync(archType, arg1, arg2, isMove: isMove, isSilent: isSilent);
        }
      }
      else {
        if (isCompress) {
          PackOper.compressSync(archType, arg1, toPath: arg2, isMove: true, isSilent: isSilent);
        }
        else {
          PackOper.uncompressSync(archType, arg1, toPath: arg2, isMove: true, isSilent: isSilent);
        }
      }
    }
    else {
      if (_options.isCmdCopy || _options.isCmdCopyNewer) {
        FileOper.xferSync(fromPaths: args, end: end, isMove: false, isNewerOnly: _options.isCmdCopyNewer, isSilent: isSilent);
      }
      else if (_options.isCmdMove || _options.isCmdMoveNewer) {
        FileOper.xferSync(fromPaths: args, end: end, isMove: true, isNewerOnly: _options.isCmdMoveNewer, isSilent: isSilent);
      }
      else if (_options.isCmdCreateDir) {
        FileOper.createDirSync(dirNames: args, isSilent: isSilent);
      }
      else if (_options.isCmdDelete) {
        FileOper.deleteSync(paths: args, isSilent: isSilent);
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execMap(String plainArg, Map<String, String> mapOrig, Map<String, String> mapPrev) {
    if (mapOrig?.isEmpty ?? true) {
      return false;
    }
    if (mapOrig.containsKey(_config.paramNameStop)) {
      hasStop = true;
      return true;
    }

    var isProcessed = false;
    var isKeyArgsFound = false;
    var mapCurr = <String, String>{};
    var keyArgs = ConfigFileLoader.ALL_ARGS;

    mapOrig.forEach((k, v) {
      if ((v != null) && v.contains(keyArgs)) {
        isKeyArgsFound = true;
      }
    });

    if (StringExt.isNullOrBlank(plainArg)) {
      if (isKeyArgsFound) {
        return false;
      }
    }
    else {
      mapOrig[keyArgs] = plainArg;
    }

    curDirName = getCurDirName(mapOrig);

    var inpFilePath = (getValue(mapOrig, key: _config.paramNameInp, mapPrev: mapPrev, canReplace: true) ?? StringExt.EMPTY);
    var hasInpFile = !StringExt.isNullOrBlank(inpFilePath);

    if (hasInpFile) {
      if (!path.isAbsolute(inpFilePath)) {
        inpFilePath = path.join(curDirName, inpFilePath);
      }

      if (inpFilePath.contains(_config.paramNameInp) ||
          inpFilePath.contains(_config.paramNameInpDir) ||
          inpFilePath.contains(_config.paramNameInpExt) ||
          inpFilePath.contains(_config.paramNameInpName) ||
          inpFilePath.contains(_config.paramNameInpNameExt) ||
          inpFilePath.contains(_config.paramNameInpPath) ||
          inpFilePath.contains(_config.paramNameInpSubDir) ||
          inpFilePath.contains(_config.paramNameInpSubPath)) {
        //throw Exception('Circular reference is not allowed: input file path is "${inpFilePath}"');
        inpFilePath = expandInpNames(inpFilePath, mapPrev);
      }

      inpFilePath = inpFilePath.getFullPath();
    }

    var subStart = (hasInpFile ? (inpFilePath.length - path.basename(inpFilePath).length) : 0);
    var inpFilePaths = getInpFilePaths(inpFilePath, curDirName);

    for (var inpFilePathEx in inpFilePaths) {
      inpFilePathEx = inpFilePathEx.adjustPath();
      mapCurr.addAll(expandMap(mapOrig, curDirName, inpFilePathEx));

      mapPrev.forEach((k, v) {
        if (!mapCurr.containsKey(k)) {
          mapCurr[k] = v;
        }
      });

      var detectPathsPattern = getValue(mapCurr, key: _config.paramNameDetectPaths, canReplace: true);

      if (StringExt.isNullOrBlank(detectPathsPattern)) {
        detectPathsRE = null;
      }
      else {
        detectPathsRE = RegExp(detectPathsPattern, caseSensitive: false);
      }

      var command = getValue(mapCurr, key: _config.paramNameCmd, canReplace: false);

      isExpandContentOnly = command.startsWith(_config.cmdNameExpand);
      canExpandContent = (isExpandContentOnly || StringExt.parseBool(getValue(mapCurr, key: _config.paramNameCanExpandContent, canReplace: false)));

      if (!StringExt.isNullOrBlank(curDirName)) {
        _logger.debug('Setting current directory to: "$curDirName"');
        Directory.current = curDirName;
      }

      if (StringExt.isNullOrBlank(command)) {
        if (_config.options.isListOnly) {
          _logger.out(jsonEncode(mapCurr) + (_config.options.isAppendSep ? ConfigFileLoader.RECORD_SEP : StringExt.EMPTY));
        }
        return true;
      }

      var outFilePath = (getValue(mapCurr, key: _config.paramNameOut, mapPrev: mapPrev, canReplace: true) ?? StringExt.EMPTY).adjustPath();
      var hasOutFile = outFilePath.isNotEmpty;

      isStdIn = (inpFilePath == StringExt.STDIN_PATH);
      isStdOut = (outFilePath == StringExt.STDOUT_PATH);

      var outFilePathEx = (hasOutFile ? outFilePath : inpFilePathEx);

      if (hasInpFile) {
        var dirName = path.dirname(inpFilePathEx);
        var inpNameExt = path.basename(inpFilePathEx);

        mapCurr[_config.paramNameInpDir] = dirName;
        mapCurr[_config.paramNameInpSubDir] = (dirName.length <= subStart ? StringExt.EMPTY : dirName.substring(subStart));
        mapCurr[_config.paramNameInpNameExt] = inpNameExt;
        mapCurr[_config.paramNameInpExt] = path.extension(inpNameExt);
        mapCurr[_config.paramNameInpName] = path.basenameWithoutExtension(inpNameExt);
        mapCurr[_config.paramNameInpPath] = inpFilePathEx;
        mapCurr[_config.paramNameInpSubPath] = inpFilePathEx.substring(subStart);
        mapCurr[_config.paramNameThis] = startCmd;

        mapCurr.forEach((k, v) {
          if ((v != null) && (k != _config.paramNameCmd) && !_inpParamNames.contains(k)) {
            mapCurr[k] = expandInpNames(v, mapCurr);
          }
        });

        if (hasOutFile) {
          outFilePathEx = expandInpNames(outFilePathEx, mapCurr);
          outFilePathEx = path.join(curDirName, outFilePathEx).getFullPath();
        }

        outFilePathEx = outFilePathEx.adjustPath();

        _logger.debug('''

Input dir:       "${mapCurr[_config.paramNameInpDir]}"
Input sub-dir:   "${mapCurr[_config.paramNameInpSubDir]}"
Input name:      "${mapCurr[_config.paramNameInpName]}"
Input extension: "${mapCurr[_config.paramNameInpExt]}"
Input name-ext:  "${mapCurr[_config.paramNameInpNameExt]}"
Input path:      "${mapCurr[_config.paramNameInpPath]}"
Input sub-path:  "${mapCurr[_config.paramNameInpSubPath]}"
        ''');
      }

      outDirName = (isStdOut ? StringExt.EMPTY : path.dirname(outFilePathEx));

      _logger.debug('''

Output dir:  "$outDirName"
Output path: "${outFilePathEx ?? StringExt.EMPTY}"
        ''');

      // if (isStdOut && !isExpandContentOnly) {
      //   throw Exception('Command execution is not supported for the output to ${StringExt.STDOUT_DISP}. Use pipe and a separate configuration file per each output.');
      // }

      var isOK = execFile(command, inpFilePathEx, outFilePathEx, mapCurr);

      if (isOK) {
        isProcessed = true;
      }
    }

    mapCurr.forEach((k, v) {
      mapPrev[k] = v;
    });

    return isProcessed;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool execFile(String cmdTemplate, String inpFilePath, String outFilePath, Map<String, String> map) {
    var command = expandInpNames(cmdTemplate.replaceAll(_config.paramNameOut, outFilePath), map)
        .replaceAll(_config.paramNameCurDir, curDirName);

    if (isExpandContentOnly) {
      var cmdParts = command.splitCommandLine();
      var argCount = cmdParts.length - 1;

      if (argCount > 0) {
        outFilePath = cmdParts[argCount];
      }

      if (argCount > 1) {
        inpFilePath = cmdParts[1];
      }
    }

    var hasInpFile = (!isStdIn && !StringExt.isNullOrBlank(inpFilePath));

    if (isExpandContentOnly && !hasInpFile) {
      throw Exception('Input file is undefined for ${_config.cmdNameExpand} operation');
    }

    var inpFile = (hasInpFile ? File(inpFilePath) : null);

    if ((inpFile != null) && !inpFile.existsSync()) {
      throw Exception('Input file is not found: "$inpFilePath"');
    }

    var hasOutFile = (!isStdOut && !StringExt.isNullOrBlank(outFilePath) && !Directory(outFilePath).existsSync());

    String tmpFilePath;

    var isSamePath = (hasInpFile && hasOutFile && path.equals(inpFilePath, outFilePath));

    if (canExpandContent && (!isExpandContentOnly || isSamePath)) {
      tmpFilePath = getActualInpFilePath(inpFilePath, outFilePath);
    }

    _logger.debug('Temp file path: "${tmpFilePath ?? StringExt.EMPTY}"');

    var outFile = (hasOutFile ? File(outFilePath) : null);

    if (!_options.isForced && hasOutFile && !isSamePath) {
      var isChanged = (outFile.compareLastModifiedStampToSync(toFile: inpFile) < 0);

      if (!isChanged) {
        isChanged = (outFile.compareLastModifiedStampToSync(toLastModifiedStamp: _config.lastModifiedStamp) < 0);
      }

      if (!isChanged) {
        _logger.information('Unchanged: "$outFilePath"');
        return false;
      }
    }

    if (hasOutFile && !isSamePath) {
      outFile.deleteIfExistsSync();
    }

    if (canExpandContent) {
      if (StringExt.isNullOrBlank(inpFilePath)) {
        throw Exception("Unable to expand file '$inpFilePath' for command $command");
      }
      expandInpContent(inpFile, outFilePath, tmpFilePath, map);
    }

    command = (getValue(map, value: command, canReplace: true) ?? StringExt.EMPTY);

    var tmpFile = (tmpFilePath != null ? File(tmpFilePath) : null);

    if (tmpFile != null) {
      command = command.replaceAll(map[_config.paramNameInp], tmpFilePath);
    }

    var isVerbose = _logger.isDetailed;

    if (_options.isListOnly || isExpandContentOnly || !isVerbose) {
      _logger.outInfo(command);
    }

    if (_options.isListOnly || isExpandContentOnly) {
      return true;
    }

    _logger.information(command);

    var isSuccess = false;
    var oldCurDir = Directory.current;
    var resultCount = 0;
    List<ProcessResult> results;

    try {
      if (StringExt.isNullOrBlank(command)) {
        // Shouldn't happen, but just in case
        return true;
      }

      var cli = command.splitCommandLine();

      if (cli[0] == _config.cmdNameSub) {
        Doul(log: _logger).exec(cli.sublist(1));
        isSuccess = true;
      }
      else {
        results = waitFor<List<ProcessResult>>(
          Shell(
            verbose: false,
            commandVerbose: false,
            commentVerbose: false,
            runInShell: false
          ).run(command)
        );

        resultCount = results?.length ?? 0;
        isSuccess = (resultCount <= 0 ? false : !results.any((x) => (x.exitCode != 0)));
      }
    }
    on Error catch (e) {
      throw Exception(e.toString());
    }
    on Exception catch (e) {
      throw Exception(e.toString());
    }
    finally {
      tmpFile?.deleteIfExistsSync();
      Directory.current = oldCurDir;

      var result = (resultCount <= 0 ? null : results[0]);

      if (result != null) {
        var unitsEnding = (resultCount == 1 ? '' : 's');

        if (!isSuccess) {
          _logger.information('Exit code$unitsEnding: ${results.map((x) => x.exitCode).join(', ')}');
          _logger.information('\n*** Error$unitsEnding:\n\n${results.errLines}\n*** Output:\n\n${results.outLines}');

          _logger.error(result.stderr ?? 'No error or warning message found');
        }
        if (result.stdout?.isNotEmpty ?? false) {
          _logger.out(result.stdout);
        }
      }
    }

    return true;
  }

  //////////////////////////////////////////////////////////////////////////////

  File expandInpContent(File inpFile, String outFilePath, String tmpFilePath, Map<String, String> map) {
    var text = StringExt.EMPTY;

    if (inpFile == null) {
      text = stdin.readAsStringSync();
    }
    else {
      text = (inpFile.readAsStringSync() ?? StringExt.EMPTY);
    }

    for (; ;) {
      map.forEach((k, v) {
        text = text.replaceAll(k, v);
      });

      var isDone = true;

      map.forEach((k, v) {
        if (text.contains(k)) {
          isDone = false;
        }
      });

      if (isDone) {
        break;
      }
    }

    if (_logger.isUltimate) {
      _logger.debug('\n...content of expanded "${inpFile.path}":\n');
      _logger.debug(text);
    }

    if (isStdOut) {
      _logger.out(text);
      return null;
    }
    else {
      var inpFilePath = inpFile.path;

      var inpDirName = path.dirname(inpFilePath);
      var inpFileName = path.basename(inpFilePath);

      var outDirName = path.dirname(outFilePath);
      var outFileName = path.basename(outFilePath);

      if (path.equals(inpFileName, outFileName)) {
        outFileName = inpFileName;
      }

      if (path.equals(inpDirName, outDirName)) {
        outDirName = inpDirName;
      }

      outFilePath = path.join(outDirName, outFileName);

      var outDir = Directory(outDirName);

      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      if (Directory(outFilePath).existsSync()) {
        outFileName = (inpFilePath.startsWith(curDirName) ? inpFilePath.substring(curDirName.length) : path.basename(inpFilePath));

        var rootPrefixLen = path.rootPrefix(outFileName).length;

        if (rootPrefixLen > 0) {
          outFileName = outFileName.substring(rootPrefixLen);
        }

        outFilePath = path.join(outFilePath, outFileName);
      }

      var tmpFile = File(tmpFilePath ?? outFilePath);

      tmpFile.deleteIfExistsSync();
      tmpFile.writeAsStringSync(text);

      if (path.equals(inpFilePath, outFilePath)) {
        tmpFile.renameSync(outFilePath);
      }

      return (isExpandContentOnly ? null : tmpFile);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String expandInpNames(String value, Map<String, String> map) {
    String inpParamName;
    var result = value;

    for (var i = 0, n = _inpParamNames.length; i < n; i++) {
      inpParamName = _inpParamNames[i];
      result = result.replaceAll(inpParamName, (map[inpParamName] ?? StringExt.EMPTY));
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  Map<String, String> expandMap(Map<String, String> map, String curDirName, String inpFilePath) {
    var newMap = <String, String>{};
    newMap.addAll(map);

    var paramNameCurDir = _config.paramNameCurDir;
    var paramNameInp = _config.paramNameInp;

    newMap.forEach((k, v) {
      if (StringExt.isNullOrBlank(k)) {
        return;
      }
      if (k == paramNameCurDir) {
        newMap[k] = curDirName;
      }
      else if (k == paramNameInp) {
        newMap[k] = inpFilePath;
      }
      else {
        if (v.contains(paramNameCurDir)) {
          newMap[k] = v.replaceAll(paramNameCurDir, curDirName);
        }

        newMap[k] = getValue(newMap, key: k, canReplace: true);
      }
    });

    return newMap;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getActualInpFilePath(String inpFilePath, String outFilePath) {
    if (isStdIn || (isExpandContentOnly && !path.equals(inpFilePath, outFilePath)) || !canExpandContent) {
      return inpFilePath;
    }
    else if (!isStdOut) {
      if (StringExt.isNullOrBlank(outFilePath)) {
        return StringExt.EMPTY;
      }
      else {
        var tmpFileName = (path.basenameWithoutExtension(outFilePath) +
            FILE_TYPE_TMP + path.extension(inpFilePath));
        var tmpDirName = path.dirname(outFilePath);

        return path.join(tmpDirName, tmpFileName);
      }
    }
    else {
      return inpFilePath;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  String getCurDirName(Map<String, String> map) {
    var curDirName = (getValue(map, key: _config.paramNameCurDir, canReplace: false) ?? StringExt.EMPTY);
    curDirName = curDirName.getFullPath();

    return curDirName;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<String> getDirList(String pattern) => DirectoryExt.pathListExSync(pattern);

  //////////////////////////////////////////////////////////////////////////////

  static List<String> getInpFilePaths(String filePath, String curDirName) {
    if (StringExt.isNullOrBlank(filePath)) {
      return [ filePath ]; // ensure at least one pass in a loop
    }

    var filePathTrim = filePath.trim();

    var lst = <String>[];

    if (filePath == StringExt.STDIN_PATH) {
      lst.add(filePath);
    }
    else {
      if (!path.isAbsolute(filePathTrim)) {
        filePathTrim = path.join(curDirName, filePathTrim).getFullPath();
      }

      lst = getDirList(filePathTrim);
    }

    if (lst.isEmpty) {
      throw Exception('No input found for: $filePath');
    }

    return lst;
  }

  //////////////////////////////////////////////////////////////////////////////

  String getValue(Map<String, String> map, {String key, String value, Map<String, String> mapPrev, bool canReplace}) {
    if ((value == null) && (key != null) && map.containsKey(key)) {
      value = map[key];
    }

    if ((canReplace ?? false) && !StringExt.isNullOrBlank(value)) {
      for (String oldValue; (oldValue != value); ) {
        oldValue = value;

        map.forEach((k, v) {
          if ((k != key) && !StringExt.isNullOrBlank(k)) {
            if ((k == _config.paramNameInp) || (k == _config.paramNameOut)) {
              if (GlobExt.isGlobPattern(v)) {
                return;
              }
            }

            value = value.replaceAll(k, v);

            var hasPath = false;

            if (value.contains(_config.paramNameCurDir)) {
              value = value.replaceAll(_config.paramNameCurDir, curDirName);
            }
            else {
              hasPath = (detectPathsRE != null) && detectPathsRE.hasMatch(k) && (k != _config.paramNameDetectPaths);
            }

            if (hasPath) {
              value = value.adjustPath();
            }
          }
        });
      }

      if ((key != null) && value.contains(key) && (mapPrev != null) && mapPrev.containsKey(key)) {
        value = value.replaceAll(key, mapPrev[key]);
      }
    }

    return (value ?? StringExt.EMPTY);
  }

  //////////////////////////////////////////////////////////////////////////////

}