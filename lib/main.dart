import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'persistence/local_storage_service.dart';
import 'state/storage_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await LocalStorageService.create();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const NetVisionApp(),
    ),
  );
}
