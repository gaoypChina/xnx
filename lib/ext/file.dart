import 'dart:io';
import 'package:path/path.dart' as Path;
import 'file_system_entity.dart';

extension FileExt on File {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final int MCSEC_PER_SEC = 1000000;

  //////////////////////////////////////////////////////////////////////////////

  int lastModifiedStampSync() {
    final theStat = statSync();

    if (theStat.type == FileSystemEntityType.notFound) {
      return null;
    }
    else {
      return theStat.modified.microsecondsSinceEpoch;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  int compareLastModifiedToSync({File toFile, DateTime toLastModified}) {
    var toLastModStamp = (toFile?.lastModifiedStampSync() ?? toLastModified?.microsecondsSinceEpoch);

    return compareLastModifiedStampToSync(toLastModifiedStamp: toLastModStamp);
  }

  //////////////////////////////////////////////////////////////////////////////

  int compareLastModifiedStampToSync({File toFile, int toLastModifiedStamp}) {
    var lastModStamp = (lastModifiedStampSync() ?? -1);
    var toLastModStamp = (toFile?.lastModifiedStampSync() ?? toLastModifiedStamp ?? -1);

    return (lastModStamp == toLastModStamp ? 0 : (lastModStamp < toLastModStamp ? -1 : 1));
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isNewerThanSync(File toFile) {
    return (compareLastModifiedToSync(toFile: toFile) > 0);
  }

  //////////////////////////////////////////////////////////////////////////////

  void setTimeSync({DateTime modified, FileStat stat}) {
    var modifiedEx = (stat?.modified ?? modified);

    if (modifiedEx == null) {
      return;
    }

    setLastModifiedSync(modifiedEx);
    setLastAccessedSync(modifiedEx);

    var newStat = statSync();

    if (modifiedEx != null) {
      var stamp1 = modifiedEx.microsecondsSinceEpoch;
      var stamp2 = newStat.modified.microsecondsSinceEpoch;

      if (stamp2 < stamp1) {
        stamp1 = ((stamp2 + MCSEC_PER_SEC) - (stamp2 % MCSEC_PER_SEC));
        modifiedEx = DateTime.fromMicrosecondsSinceEpoch(stamp1);

        setLastModifiedSync(modifiedEx);
        newStat = statSync();
        stamp2 = newStat.modified.microsecondsSinceEpoch;

        if (stamp2 < stamp1) {
          stamp1 += MCSEC_PER_SEC;
          modifiedEx = DateTime.fromMicrosecondsSinceEpoch(stamp1);
          setLastModifiedSync(modifiedEx);
        }

        setLastAccessedSync(modifiedEx);
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void xferSync(String toPath, {bool isMove = false, bool isNewerOnly = false, bool isSilent = false}) {
    // Ensuring source file exists

    if (!existsSync()) {
      throw Exception('Copy failed, as source file "${path}" was not found');
    }

    // Sanity check

    if (isSamePath(toPath)) {
      throw Exception('Unable to copy: source and target are the same: "${path}"');
    }

    // Getting destination path and directory, as well as checking what's newer

    var isToDir = Directory(toPath).existsSync();
    var isToDirValid = isToDir;
    var toPathEx = (isToDir ? Path.join(toPath, Path.basename(path)) : toPath);
    var toDirName = (isToDir ? toPath : Path.dirname(toPath));
    var canDo = (!isNewerOnly || isNewerThanSync(File(toPathEx)));

    // Setting operation flag depending on whether the destination is newer or not

    if (!isToDirValid) {
      Directory(toDirName).createSync();
    }

    if (isMove) {
      if (canDo) {
        if (!isSilent) {
          print('Moving file "${path}"');
        }
        renameSync(toPathEx);
      }
      else {
        if (!isSilent) {
          print('Deleting file "${path}"');
        }
        deleteSync();
      }
    }
    else if (canDo) {
      if (!isSilent) {
        print('Copying file "${path}"');
      }

      var fromStat = statSync();
      copySync(toPathEx);
      File(toPathEx).setTimeSync(stat: fromStat);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}