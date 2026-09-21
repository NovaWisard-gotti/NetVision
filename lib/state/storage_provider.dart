import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../persistence/local_storage_service.dart';

/// Se sobreescribe en `main.dart` una vez que [LocalStorageService.create]
/// termina de inicializarse, antes de correr la app. Todos los demás
/// providers dependen de este para persistir datos localmente.
final storageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError(
      'storageServiceProvider debe sobreescribirse en main.dart antes de runApp.');
});
