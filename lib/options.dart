import 'dart:io';
import 'package:archive/archive.dart';
import 'package:args/args.dart';
import 'package:doul/config_file_info.dart';
import 'package:doul/config_file_loader.dart';
import 'package:doul/ext/directory.dart';
import 'package:doul/ext/glob.dart';
import 'package:path/path.dart' as Path;

import 'package:doul/ext/string.dart';
import 'pack_oper.dart';
import 'log.dart';
import 'ext/stdin.dart';

class Options {

  //////////////////////////////////////////////////////////////////////////////

  static final Map<String, Object> APPEND_SEP = {
    'name': 'append-sep',
    'abbr': 's',
    'help': 'append record separator "${ConfigFileLoader.RECORD_SEP}" when filtering input config file (for "${LIST_ONLY['name']}" exclusively)',
    'negatable': false,
  };
  static final Map<String, Object> COMPRESSION = {
    'name': 'compression',
    'abbr': 'p',
    'help': 'compression level for archiving-related operations (${Deflate.BEST_SPEED}..${Deflate.BEST_COMPRESSION}) excepting BZip2',
    'valueHelp': 'LEVEL',
    'defaultsTo': PackOper.DEFAULT_COMPRESSION.toString(),
  };
  static final Map<String, Object> CONFIG = {
    'name': 'config',
    'abbr': 'c',
    'help': 'configuration file in json format',
    'valueHelp': 'FILE',
    'defaultsTo': null,
  };
  static final Map<String, Object> FORCE_CONVERT = {
    'name': 'force',
    'abbr': 'f',
    'help': 'ignore timestamps and force conversion',
    'negatable': false,
  };
  static final Map<String, Object> HELP = {
    'name': 'help',
    'abbr': 'h',
    'help': 'this help screen',
    'negatable': false,
  };
  static final Map<String, Object> LIST_ONLY = {
    'name': 'list-only',
    'abbr': 'l',
    'help': 'display all commands, but do not execute those; if no command specified, then show config',
    'negatable': false,
  };
  static final Map<String, Object> QUIET = {
    'name': 'quiet',
    'abbr': 'q',
    'help': 'quiet mode (no output except when \"${StringExt.STDOUT_PATH}\" is specified as output)',
    'negatable': false,
  };
  static final Map<String, Object> START_DIR = {
    'name': 'dir',
    'abbr': 'd',
    'help': 'startup directory',
    'valueHelp': 'DIR',
    'defaultsTo': '.',
  };
  static final Map<String, Object> VERBOSITY = {
    'name': 'verbosity',
    'abbr': 'v',
    'help': 'how much information to show: 0-3',
    'valueHelp': 'LEVEL',
    'defaultsTo': '1',
  };
  static final Map<String, Object> XARGS = {
    'name': 'xargs',
    'abbr': 'x',
    'help': 'treat each plain argument independently (e.g. can pass multiple filenames as arguments)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_COPY = {
    'name': 'copy',
    'help': 'just copy file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_COPY_NEWER = {
    'name': 'copy-newer',
    'help': 'just copy more recently updated file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_DELETE = {
    'name': 'delete',
    'help': 'just delete file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_CREATE_DIR = {
    'name': 'mkdir',
    'help': 'just create directories passed as plain arguments',
    'negatable': false,
  };
  static final Map<String, Object> CMD_MOVE = {
    'name': 'move',
    'help': 'just move file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_MOVE_NEWER = {
    'name': 'move-newer',
    'help': 'just move more recently updated file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_REMOVE = {
    'name': 'remove',
    'help': 'just the same as --delete',
    'negatable': false,
  };
  static final Map<String, Object> CMD_RENAME = {
    'name': 'rename',
    'help': 'just the same as --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_RENAME_NEWER = {
    'name': 'rename-newer',
    'help': 'just the same as --move-newer',
    'negatable': false,
  };
  static final Map<String, Object> CMD_BZ2 = {
    'name': 'bz2',
    'help': 'just compress a single source file to a single destination BZip2 file, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNBZ2 = {
    'name': 'unbz2',
    'help': 'just decompress a single BZip2 file to a single destination file, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_GZ = {
    'name': 'gz',
    'help': 'just compress a single source file to a single GZip file, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNGZ = {
    'name': 'ungz',
    'help': 'just decompress a single GZip file to a single destination file, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_PACK = {
    'name': 'pack',
    'help': 'just compress source files and/or directories to a single destination archive file depending on its extension, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNPACK = {
    'name': 'unpack',
    'help': 'just decompress a single source archive file to destination files and/or directories depending on source extension, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_TAR = {
    'name': 'tar',
    'help': 'just create a single destination archive file containing source files and/or directories, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNTAR = {
    'name': 'untar',
    'help': 'just untar a single archive file to a destination directory, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_TAR_BZ2 = {
    'name': 'tbz',
    'help': 'just a combination of --tar and --bz2, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNTAR_BZ2 = {
    'name': 'untbz',
    'help': 'just a combination of --untar and --unbz2, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_TAR_GZ = {
    'name': 'tgz',
    'help': 'just a combination of --tar and --gz, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNTAR_GZ = {
    'name': 'untgz',
    'help': 'just a combination of --untar and --ungz, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_TAR_ZLIB = {
    'name': 'tzl',
    'help': 'just a combination of --tar and --zlib, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNTAR_ZLIB = {
    'name': 'untzl',
    'help': 'just a combination of --untar and --unzlib, can be used with --move',
    'negatable': false,
  };
  static final Map<String, Object> CMD_ZIP = {
    'name': 'zip',
    'help': 'just zip source files and/or directories to a single destination archive file, can be used with with --move to delete source to delete source',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNZIP = {
    'name': 'unzip',
    'help': 'just unzip single archive file to destination directory, can be used with with --move to delete source to delete source',
    'negatable': false,
  };
  static final Map<String, Object> CMD_ZLIB = {
    'name': 'zlib',
    'help': 'just compress a single source file to a single ZLib file, can be used with with --move to delete source to delete source',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNZLIB = {
    'name': 'unzlib',
    'help': 'just decompress a single ZLib file to a single destination file, can be used with with --move to delete source to delete source',
    'negatable': false,
  };

  //////////////////////////////////////////////////////////////////////////////

  static final String APP_NAME = 'doul';
  static final String FILE_TYPE_CFG = '.json';
  static final String FILE_MASK_CFG = '${GlobExt.ALL}${FILE_TYPE_CFG}';

  static final RegExp RE_OPT_CONFIG = RegExp('^[\\-]([\\-]${CONFIG['name']}|${CONFIG['abbr']})([\\=]|\$)', caseSensitive: true);
  static final RegExp RE_OPT_START_DIR = RegExp('^[\\-]([\\-]${START_DIR['name']}|${START_DIR['abbr']})([\\=]|\$)', caseSensitive: true);

  //////////////////////////////////////////////////////////////////////////////

  bool _asXargs;
  bool get asXargs => _asXargs;

  int _compression;
  int get compression => _compression;

  ConfigFileInfo _configFileInfo;
  ConfigFileInfo get configFileInfo => _configFileInfo;

  bool _isAppendSep;
  bool get isAppendSep => _isAppendSep;

  bool _isForced;
  bool get isForced => _isForced;

  bool _isListOnly;
  bool get isListOnly => _isListOnly;

  List<String> _plainArgs;
  List<String> get plainArgs => _plainArgs;

  String _startDirName;
  String get startDirName => _startDirName;

  //////////////////////////////////////////////////////////////////////////////

  bool get isCmd => (_isCmdCopy || _isCmdCopyNewer || _isCmdDelete || _isCmdCreate || _isCmdMove || _isCmdMoveNewer ||  isCmdCompress || isCmdDecompress);

  //////////////////////////////////////////////////////////////////////////////

  PackType _archType;
  PackType get archType => _archType;

  bool _isCmdCompress;
  bool get isCmdCompress => _isCmdCompress;

  bool _isCmdCopy;
  bool get isCmdCopy => _isCmdCopy;

  bool _isCmdCopyNewer;
  bool get isCmdCopyNewer => _isCmdCopyNewer;

  bool _isCmdDecompress;
  bool get isCmdDecompress => _isCmdDecompress;

  bool _isCmdDelete;
  bool get isCmdDelete => _isCmdDelete;

  bool _isCmdCreate;
  bool get isCmdCreateDir => _isCmdCreate;

  bool _isCmdMove;
  bool get isCmdMove => _isCmdMove;

  bool _isCmdMoveNewer;
  bool get isCmdMoveNewer => _isCmdMoveNewer;

  //////////////////////////////////////////////////////////////////////////////

  String getConfigFullPath(List<String> args) {
    for (var arg in args) {
      if (RE_OPT_CONFIG.hasMatch(arg)) {
        return configFileInfo.filePath.getFullPath();
      }
      if (RE_OPT_START_DIR.hasMatch(arg)) {
        break;
      }
    }

    return Path.join(startDirName, configFileInfo.filePath).getFullPath();
  }

  //////////////////////////////////////////////////////////////////////////////

  void parseArgs(List<String> args) {
    Log.level = Log.LEVEL_DEFAULT;

    var errMsg = StringExt.EMPTY;
    var isHelp = false;

    _configFileInfo = null;
    _startDirName = null;
    _isAppendSep = false;
    _isListOnly = false;

    _isCmdCompress = false;
    _isCmdDecompress = false;
    _isCmdMove = false;
    _isCmdMoveNewer = false;
    _isCmdDelete = false;


    var isLogLevelSet = false;

    final parser = ArgParser()
      ..addFlag(QUIET['name'], abbr: QUIET['abbr'], help: QUIET['help'], negatable: QUIET['negatable'], callback: (value) {
        if (value) {
          Log.level = Log.LEVEL_SILENT;
          isLogLevelSet = true;
        }
      })
      ..addOption(VERBOSITY['name'], abbr: VERBOSITY['abbr'], help: VERBOSITY['help'], valueHelp: VERBOSITY['valueHelp'], defaultsTo: VERBOSITY['defaultsTo'], callback: (value) {
        if (!isLogLevelSet) {
          Log.userLevel = int.parse(value);
        }
      })
      ..addFlag(XARGS['name'], abbr: XARGS['abbr'], help: XARGS['help'], negatable: XARGS['negatable'], callback: (value) {
        _asXargs = value;
      })
      ..addOption(CONFIG['name'], abbr: CONFIG['abbr'], help: CONFIG['help'], valueHelp: CONFIG['valueHelp'], defaultsTo: CONFIG['defaultsTo'], callback: (value) {
        _configFileInfo = ConfigFileInfo(value);
      })
      ..addFlag(LIST_ONLY['name'], abbr: LIST_ONLY['abbr'], help: LIST_ONLY['help'], negatable: LIST_ONLY['negatable'], callback: (value) {
        _isListOnly = value;
      })
      ..addFlag(APPEND_SEP['name'], abbr: APPEND_SEP['abbr'], help: APPEND_SEP['help'], negatable: APPEND_SEP['negatable'], callback: (value) {
        _isAppendSep = value;
      })
      ..addFlag(FORCE_CONVERT['name'], abbr: FORCE_CONVERT['abbr'], help: FORCE_CONVERT['help'], negatable: FORCE_CONVERT['negatable'], callback: (value) {
        _isForced = value;
      })
      ..addFlag(HELP['name'], abbr: HELP['abbr'], help: HELP['help'], negatable: HELP['negatable'], callback: (value) {
        isHelp = value;
      })
      ..addOption(START_DIR['name'], abbr: START_DIR['abbr'], help: START_DIR['help'], valueHelp: START_DIR['valueHelp'], defaultsTo: START_DIR['defaultsTo'], callback: (value) {
        _startDirName = (value == null ? StringExt.EMPTY : (value as String).getFullPath());
      })
      ..addOption(COMPRESSION['name'], abbr: COMPRESSION['abbr'], help: COMPRESSION['help'], valueHelp: COMPRESSION['valueHelp'], defaultsTo: COMPRESSION['defaultsTo'], callback: (value) {
        _compression = int.parse(value);
      })
      ..addFlag(CMD_COPY['name'], help: CMD_COPY['help'], negatable: CMD_COPY['negatable'], callback: (value) {
        _isCmdCopy = value;
      })
      ..addFlag(CMD_COPY_NEWER['name'], help: CMD_COPY_NEWER['help'], negatable: CMD_COPY_NEWER['negatable'], callback: (value) {
        _isCmdCopyNewer = value;
      })
      ..addFlag(CMD_MOVE['name'], help: CMD_MOVE['help'], negatable: CMD_MOVE['negatable'], callback: (value) {
        if (value) {
          _isCmdMove = value;
        }
      })
      ..addFlag(CMD_MOVE_NEWER['name'], help: CMD_MOVE_NEWER['help'], negatable: CMD_MOVE_NEWER['negatable'], callback: (value) {
        if (value) {
          _isCmdMoveNewer = value;
        }
      })
      ..addFlag(CMD_RENAME['name'], help: CMD_RENAME['help'], negatable: CMD_RENAME['negatable'], callback: (value) {
        if (value) {
          _isCmdMove = value;
        }
      })
      ..addFlag(CMD_RENAME_NEWER['name'], help: CMD_RENAME_NEWER['help'], negatable: CMD_RENAME_NEWER['negatable'], callback: (value) {
        if (value) {
          _isCmdMoveNewer = value;
        }
      })
      ..addFlag(CMD_CREATE_DIR['name'], help: CMD_CREATE_DIR['help'], negatable: CMD_CREATE_DIR['negatable'], callback: (value) {
        _isCmdCreate = value;
      })
      ..addFlag(CMD_DELETE['name'], help: CMD_DELETE['help'], negatable: CMD_DELETE['negatable'], callback: (value) {
        if (value) {
          _isCmdDelete = value;
        }
      })
      ..addFlag(CMD_REMOVE['name'], help: CMD_REMOVE['help'], negatable: CMD_REMOVE['negatable'], callback: (value) {
        if (value) {
          _isCmdDelete = value;
        }
      })
      ..addFlag(CMD_BZ2['name'], help: CMD_BZ2['help'], negatable: CMD_BZ2['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = value;
          _isCmdDecompress = !value;
          _archType = PackType.Bz2;
        }
      })
      ..addFlag(CMD_UNBZ2['name'], help: CMD_UNBZ2['help'], negatable: CMD_UNBZ2['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = !value;
          _isCmdDecompress = value;
          _archType = PackType.Bz2;
        }
      })
      ..addFlag(CMD_GZ['name'], help: CMD_GZ['help'], negatable: CMD_GZ['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = value;
          _isCmdDecompress = !value;
          _archType = PackType.Gz;
        }
      })
      ..addFlag(CMD_UNGZ['name'], help: CMD_UNGZ['help'], negatable: CMD_UNGZ['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = !value;
          _isCmdDecompress = value;
          _archType = PackType.Gz;
        }
      })
      ..addFlag(CMD_TAR['name'], help: CMD_TAR['help'], negatable: CMD_TAR['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = value;
          _isCmdDecompress = !value;
          _archType = PackType.Tar;
        }
      })
      ..addFlag(CMD_UNTAR['name'], help: CMD_UNTAR['help'], negatable: CMD_UNTAR['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = !value;
          _isCmdDecompress = value;
          _archType = PackType.Tar;
        }
      })
      ..addFlag(CMD_TAR_BZ2['name'], help: CMD_TAR_BZ2['help'], negatable: CMD_TAR_BZ2['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = value;
          _isCmdDecompress = !value;
          _archType = PackType.TarBz2;
        }
      })
      ..addFlag(CMD_UNTAR_BZ2['name'], help: CMD_UNTAR_BZ2['help'], negatable: CMD_UNTAR_BZ2['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = !value;
          _isCmdDecompress = value;
          _archType = PackType.TarBz2;
        }
      })
      ..addFlag(CMD_TAR_GZ['name'], help: CMD_TAR_GZ['help'], negatable: CMD_TAR_GZ['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = value;
          _isCmdDecompress = !value;
          _archType = PackType.TarGz;
        }
      })
      ..addFlag(CMD_UNTAR_GZ['name'], help: CMD_UNTAR_GZ['help'], negatable: CMD_UNTAR_GZ['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = !value;
          _isCmdDecompress = value;
          _archType = PackType.TarGz;
        }
      })
      ..addFlag(CMD_TAR_ZLIB['name'], help: CMD_TAR_ZLIB['help'], negatable: CMD_TAR_ZLIB['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = value;
          _isCmdDecompress = !value;
          _archType = PackType.TarZlib;
        }
      })
      ..addFlag(CMD_UNTAR_ZLIB['name'], help: CMD_UNTAR_ZLIB['help'], negatable: CMD_UNTAR_ZLIB['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = !value;
          _isCmdDecompress = value;
          _archType = PackType.TarZlib;
        }
      })
      ..addFlag(CMD_ZIP['name'], help: CMD_ZIP['help'], negatable: CMD_ZIP['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = value;
          _isCmdDecompress = !value;
          _archType = PackType.Zip;
        }
      })
      ..addFlag(CMD_UNZIP['name'], help: CMD_UNZIP['help'], negatable: CMD_UNZIP['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = !value;
          _isCmdDecompress = value;
          _archType = PackType.Zip;
        }
      })
      ..addFlag(CMD_ZLIB['name'], help: CMD_ZLIB['help'], negatable: CMD_ZLIB['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = value;
          _isCmdDecompress = !value;
          _archType = PackType.Zlib;
        }
      })
      ..addFlag(CMD_UNZLIB['name'], help: CMD_UNZLIB['help'], negatable: CMD_UNZLIB['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = !value;
          _isCmdDecompress = value;
          _archType = PackType.Zlib;
        }
      })
      ..addFlag(CMD_PACK['name'], help: CMD_PACK['help'], negatable: CMD_PACK['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = value;
          _isCmdDecompress = !value;
          _archType = null;
        }
      })
      ..addFlag(CMD_UNPACK['name'], help: CMD_UNPACK['help'], negatable: CMD_UNPACK['negatable'], callback: (value) {
        if (value) {
          _isCmdCompress = !value;
          _isCmdDecompress = value;
          _archType = null;
        }
      })
    ;

    if ((args == null) || args.isEmpty) {
      printUsage(parser);
    }

    try {
      var result = parser.parse(args);

      _plainArgs = <String>[];
      _plainArgs.addAll(result.rest);

      if (_asXargs) {
        var inpArgs = stdin.readAsStringSync().split('\n');

        for (var i = 0, n = inpArgs.length; i < n; i++) {
          if (inpArgs[i].trim().isNotEmpty) {
            _plainArgs.add(inpArgs[i]);
          }
        }
      }
    }
    catch (e) {
      isHelp = true;
      errMsg = e?.toString();
    }

    if (isHelp) {
      printUsage(parser, error: errMsg);
    }

    if (StringExt.isNullOrBlank(_startDirName)) {
      _startDirName = null;
    }

    _startDirName = Path.canonicalize(_startDirName ?? '');

    if (!isCmd) {
      var filePath = _configFileInfo.filePath;

      if (filePath != StringExt.STDIN_PATH) {
        if (filePath.isEmpty) {
          filePath = Path.join(_startDirName, Path.basename(_startDirName) + FILE_TYPE_CFG);

          if (!File(filePath).existsSync()) {
            var lst = DirectoryExt.pathListExSync(Path.join(_startDirName, FILE_MASK_CFG));
            filePath = ((lst.length <= 0 ? null : lst.first) ?? StringExt.EMPTY);
          }
        }
        else {
          if (StringExt.isNullOrBlank(Path.extension(filePath))) {
            filePath = Path.setExtension(filePath, FILE_TYPE_CFG);
          }

          if (StringExt.isNullOrBlank(filePath)) {
            printUsage(parser, error: 'Configuration file is not found');
          }

          if (!Path.isAbsolute(filePath)) {
            filePath = getConfigFullPath(args);
          }

          var configFile = File(filePath);

          if (!configFile.existsSync()) {
            var dirName = Path.dirname(filePath);
            var fileName = Path.basename(dirName) + FILE_TYPE_CFG;

            filePath = Path.join(dirName, fileName);
          }
        }

        _configFileInfo.filePath = filePath;
      }
    }

    StringExt.initEnvironmentVariables();
    Log.information('OS: ' + StringExt.ENVIRONMENT['OSTYPE'] ?? '<unknown>');

    if (!StringExt.isNullOrBlank(_startDirName)) {
        Log.information('Setting current directory to: "${_startDirName}"');
        Directory.current = _startDirName;
    }

    unquotePlainArgs();
  }

  //////////////////////////////////////////////////////////////////////////////

  static void printUsage(ArgParser parser, {String error}) {
    final hasError = !StringExt.isNullOrBlank(error);

    stderr.writeln('''

USAGE:

${APP_NAME} [OPTIONS]

${parser.usage}

See README.md file for more details or visit https://phrasehacker.wordpress.com/software/doul/
      ''');

    throw Exception(hasError ? error : HELP['name']);
  }

  //////////////////////////////////////////////////////////////////////////////

  void unquotePlainArgs() {
    var newArgs = <String>[];
    var argCount = (_plainArgs?.length ?? 0);

    for (var i = 0; i < argCount; i++) {
      var arg = _plainArgs[i].unquote();

      if (arg.isNotEmpty) {
        newArgs.add(arg);
      }
    }

    _plainArgs = newArgs;
  }

  //////////////////////////////////////////////////////////////////////////////
}
