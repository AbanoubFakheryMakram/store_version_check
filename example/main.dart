// A minimal splash-style flow. Run it inside any Flutter app that depends on `store_version_check`.
import 'package:flutter/material.dart';
import 'package:store_version_check/store_version_check.dart';
import 'package:url_launcher/url_launcher.dart';

// Keep ONE instance for the app's lifetime so the check happens once per session.
final storeVersionChecker = StoreVersionChecker(
  // Debug trick: uncomment to see the dialog on any build without publishing a release.
  // Use StoreVersionChecker.simulated(storeVersion: '99.0.0') instead of the line below.
  onError: (error, stack) => debugPrint('Update check failed: $error'),
);

Future<void> checkForUpdate(BuildContext context) async {
  final result = await storeVersionChecker.checkOncePerSession();
  if (result == null || !result.isUpdateAvailable || !context.mounted) return;

  final update = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('New update available'),
      content: Text('Version ${result.storeVersion} is out (you have ${result.currentVersion}).'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update')),
      ],
    ),
  );
  if (update == true) {
    await launchUrl(Uri.parse(result.storeUrl!), mode: LaunchMode.externalApplication);
  }
}
