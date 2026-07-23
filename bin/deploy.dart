import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

// --- CONFIGURATION VALUES ---
const String firebaseAppId = "1:216680883540:android:691d8949948b9e157a54c1";

//const String firebaseAppId = "YOUR_FIREBASE_ANDROID_APP_ID";
const String testerGroups = "internal-testers"; // Tester group name in Firebase Console
// ----------------------------

void main() async {
  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    print("❌ ERROR: pubspec.yaml file not found in current root working directory.");
    exit(1);
  }

  print("🔄 Reading package settings out of pubspec.yaml...");
  final pubspecContent = await pubspecFile.readAsString();
  final doc = loadYaml(pubspecContent);
  final String currentVersion = doc['version']?.toString() ?? '1.0.0+1';

  // Split version parts out (e.g. 1.0.2+5)
  final versionParts = currentVersion.split('+');
  final versionName = versionParts[0];
  final int currentBuildNumber = int.parse(versionParts[1]);
  final int nextBuildNumber = currentBuildNumber + 1;
  final String nextFullVersion = "$versionName+$nextBuildNumber";

  print("🚀 Bumping Android target version string: $currentVersion ➡️ $nextFullVersion");

  // Increment the build code dynamically inside the file string buffer
  final updatedContent = pubspecContent.replaceFirst(
    "version: $currentVersion",
    "version: $nextFullVersion",
  );
  await pubspecFile.writeAsString(updatedContent);

 // print("🧹 Cleaning local workspace caches...");
 // await runCommand('flutter', ['clean']);
  //await runCommand('flutter', ['pub', 'get']);
print("🧹 Cleaning local Android build artifacts manually...");
  // ⚡ This targets and clears only the Android build directory safely
  final buildDir = Directory('build/app');
  if (await buildDir.exists()) {
    await buildDir.delete(recursive: true);
  }

  print("📦 Fetching dependencies...");
  await runCommand('flutter', ['pub', 'get']);

  //print("📦 Generating signed compilation binary...");
  // Automatically attaches your structural environment mapping properties
  //await runCommand('flutter', [
   // 'build', 'apk', '--release', '--dart-define-from-file=.env'
 // ]);

//  AFTER (Slices your APK size by up to 60%)

print("📦 Generating signed compilation binary...");
await runCommand('flutter', [
  'build', 'apk', 
  '--release', 
  '--split-per-abi', // ⚡ Splits the single giant APK into 3 small, optimized APKs
  '--dart-define-from-file=.env'
]);

  // Read release details interactively via the standard terminal pipe stream
  stdout.write("\n📝 Enter release notes for testers (Press Enter to finish): ");
  final String? releaseNotes = stdin.readLineSync(encoding: utf8);

  print("📤 Uploading binary artifact straight to Firebase App Distribution pipeline...");
  await runCommand('firebase', [
    'appdistribution:distribute',
    'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
    '--app', firebaseAppId,
    '--groups', testerGroups,
    '--release-notes', releaseNotes ?? 'Automated Flutter Engine Deployment'
  ]);

  print("\n✅ Deployment successful! Build version $nextFullVersion is live.");
}

/// Helper block to cleanly pipe external shell streams straight back to VS Code
Future<void> runCommand(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments, runInShell: true);
  
  // Forward stdout and stderr outputs seamlessly
  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    print("❌ Critical breakdown: Command '$executable ${arguments.join(' ')}' exited with code $exitCode");
    exit(exitCode);
  }
}
