import 'package:test/test.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/pack_oper.dart';
//import 'package:xnx/src/ext/path.dart';
//import 'package:xnx/src/pack_oper.dart';

import 'helper.dart';

void main() {
  Helper.forEachMemoryFileSystem((fileSystem) {
    group('Operation', () {
      test('getPackPath', () {
        Helper.initFileSystem(fileSystem);

        var fromPath = Path.join('dir', 'a.txt');
        var toPath = Path.join('dir', 'b.txt');

        expect(PackOper.getPackPath(PackType.Bz2, fromPath, null), fromPath + '.bz2');
        expect(PackOper.getPackPath(PackType.Bz2, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.Gz, fromPath, null), fromPath + '.gz');
        expect(PackOper.getPackPath(PackType.Gz, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.Tar, fromPath, null), fromPath + '.tar');
        expect(PackOper.getPackPath(PackType.Tar, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.TarBz2, fromPath, null), fromPath + '.bz2');
        expect(PackOper.getPackPath(PackType.TarBz2, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.TarGz, fromPath, null), fromPath + '.gz');
        expect(PackOper.getPackPath(PackType.TarGz, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.TarZlib, fromPath, null), fromPath + '.Z');
        expect(PackOper.getPackPath(PackType.TarZlib, fromPath, toPath), toPath);
        expect(PackOper.getPackPath(PackType.Zip, fromPath, null), fromPath + '.zip');
        expect(PackOper.getPackPath(PackType.Zip, fromPath, toPath), toPath);
      });
      test('getPackType - by pack type', () {
        Helper.initFileSystem(fileSystem);

        expect(PackOper.getPackType(PackType.Bz2, null), PackType.Bz2);
        expect(PackOper.getPackType(PackType.Bz2, 'a.txt'), PackType.Bz2);
        expect(PackOper.getPackType(PackType.Gz, null), PackType.Gz);
        expect(PackOper.getPackType(PackType.Gz, 'a.txt'), PackType.Gz);
        expect(PackOper.getPackType(PackType.Tar, null), PackType.Tar);
        expect(PackOper.getPackType(PackType.Tar, 'a.txt'), PackType.Tar);
        expect(PackOper.getPackType(PackType.TarBz2, null), PackType.TarBz2);
        expect(PackOper.getPackType(PackType.TarBz2, 'a.txt'), PackType.TarBz2);
        expect(PackOper.getPackType(PackType.TarGz, null), PackType.TarGz);
        expect(PackOper.getPackType(PackType.TarGz, 'a.txt'), PackType.TarGz);
        expect(PackOper.getPackType(PackType.TarZlib, null), PackType.TarZlib);
        expect(PackOper.getPackType(PackType.TarZlib, 'a.txt'), PackType.TarZlib);
        expect(PackOper.getPackType(PackType.Zip, null), PackType.Zip);
        expect(PackOper.getPackType(PackType.Zip, 'a.txt'), PackType.Zip);
      });
      test('getPackType - by file type', () {
        Helper.initFileSystem(fileSystem);

        var path = Path.join('dir', 'a.txt');

        expect(PackOper.getPackType(null, null), null);
        expect(PackOper.getPackType(null, path), null);

        expect(PackOper.getPackType(null, path + '.bz2'), PackType.Bz2);
        expect(PackOper.getPackType(null, path + '.tbz'), PackType.TarBz2);

        expect(PackOper.getPackType(null, path + '.gz'), PackType.Gz);
        expect(PackOper.getPackType(null, path + '.tgz'), PackType.TarGz);

        expect(PackOper.getPackType(null, path + '.z'), PackType.Zlib);
        expect(PackOper.getPackType(null, path + '.Z'), PackType.Zlib);
        expect(PackOper.getPackType(null, path + '.tz'), PackType.TarZlib);
      });
      test('getUnpackPath', () {
        Helper.initFileSystem(fileSystem);

        var dirName = 'dir';
        Path.fileSystem.directory(dirName).createSync();

        var fromPath = Path.join(dirName, 'a.txt');
        var toPath = Path.join(dirName, 'b.txt');

        expect(PackOper.getUnpackPath(PackType.Bz2, fromPath + '.bz2', null), fromPath);
        expect(PackOper.getUnpackPath(PackType.Bz2, fromPath + '.bz2', toPath), toPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.bz2', null), fromPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.bz2', dirName), fromPath);

        expect(PackOper.getUnpackPath(PackType.TarZlib, fromPath + '.tar.Z', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(PackType.TarZlib, fromPath + '.tar.Z', toPath), toPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.tar.Z', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(null, fromPath + '.tar.Z', dirName), fromPath + '.tar');

        expect(PackOper.getUnpackPath(PackType.TarGz, fromPath + '.tgz', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(PackType.TarGz, fromPath + '.tgz', toPath), toPath);
        expect(PackOper.getUnpackPath(null, fromPath + '.tgz', null), fromPath + '.tar');
        expect(PackOper.getUnpackPath(null, fromPath + '.tgz', dirName), fromPath + '.tar');
      });
      test('isPackTypeTar', () {
        Helper.initFileSystem(fileSystem);

        expect(PackOper.isPackTypeTar(PackType.Bz2), false);
        expect(PackOper.isPackTypeTar(PackType.Gz), false);

        expect(PackOper.isPackTypeTar(PackType.Zip), false);
        expect(PackOper.isPackTypeTar(PackType.Zlib), false);

        expect(PackOper.isPackTypeTar(PackType.Tar), true);
        expect(PackOper.isPackTypeTar(PackType.TarBz2), true);

        expect(PackOper.isPackTypeTar(PackType.TarGz), true);
        expect(PackOper.isPackTypeTar(PackType.TarZlib), true);
      });
      test('archiveSync/unarchiveSync', () {
        Helper.initFileSystem(fileSystem);

        print('*** The "archive" package does not seem to be testable on MemoryFileSystem yet');

        // var fromDir = Path.fileSystem.directory(Path.join('dir', 'sub-dir'));
        // fromDir.createSync(recursive: true);

        // Path.fileSystem.directory(Path.join(fromDir.path, 'sub-sub-dir')).createSync();
        // Path.fileSystem.file(Path.join(fromDir.path, 'a.txt')).createSync();
        // Path.fileSystem.file(Path.join(fromDir.path, 'b.txt')).createSync();
        // Path.fileSystem.file(Path.join(fromDir.path, 'c.txt')).createSync();
        // Path.fileSystem.file(Path.join(fromDir.path, 'd.txt')).createSync();
        // Path.fileSystem
        //     .file(Path.join(fromDir.path, 'sub-sub-dir', 'a.csv'))
        //     .createSync();

        // var toDir = Path.fileSystem.directory('zip')..createSync();
        // var toPath = Path.join(toDir.path, 'test.zip');

        // PackOper.archiveSync(
        //   PackType.Zip,
        //   [fromDir.parent.path, toPath],
        //   isMove: true,
        //   isSilent: true
        // );

        // expect(Path.fileSystem.file(toPath).existsSync(), true);
        // expect(fromDir.parent.existsSync(), false);

        // PackOper.unarchiveSync(
        //   PackType.Zip,
        //   fromDir.path,
        //   toPath,
        //   isMove: false,
        //   isSilent: true
        // );

        // expect(Path.fileSystem.file(toPath).existsSync(), true);
        // expect(fromDir.parent.listSync().length, 5);

        // fromDir.deleteSync(recursive: true);
        // toDir.deleteSync(recursive: true);
      });
    });
  });
}
