import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class BackupService {
  Future<String> createBackup() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = '${backupDir.path}/jaypos_backup_$timestamp.zip';

    final encoder = ZipEncoder();
    final archive = Archive();

    final dbFile = File('${dir.path}/jaypos.db');
    if (await dbFile.exists()) {
      final bytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('jaypos.db', bytes.length, bytes));
    }

    final imagesDir = Directory('${dir.path}/images');
    if (await imagesDir.exists()) {
      await for (final file in imagesDir.list()) {
        if (file is File) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile('images/${file.uri.pathSegments.last}', bytes.length, bytes));
        }
      }
    }

    final encoded = encoder.encode(archive);
    if (encoded != null) {
      await File(backupPath).writeAsBytes(encoded);
    }

    return backupPath;
  }

  Future<bool> restoreBackup(String zipPath) async {
    try {
      final file = File(zipPath);
      final bytes = await file.readAsBytes();
      final decoder = ZipDecoder();
      final archive = decoder.decodeBytes(bytes);

      final dir = await getApplicationDocumentsDirectory();

      for (final file in archive) {
        final filePath = '${dir.path}/${file.name}';
        if (file.isFile) {
          await File(filePath).writeAsBytes(file.content as List<int>);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});
