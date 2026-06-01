# Einrichtung auf GitHub

## 1. Dateien hochladen

Lade den kompletten Inhalt dieses Ordners in dein GitHub-Repository.

Wichtig sind mindestens:

- lib/main.dart
- pubspec.yaml
- .github/workflows/android-apk.yml

## 2. Falls .github nicht sichtbar ist

Dann in GitHub:

Add file -> Create new file

Als Dateiname exakt:

.github/workflows/android-apk.yml

Dann den Inhalt aus ANDROID_WORKFLOW_ZUM_KOPIEREN.yml einfügen.

## 3. APK bauen

Actions -> Build Android APK -> Run workflow

Nach dem erfolgreichen Build:

Workflow-Lauf öffnen -> Artifacts -> custom-soundboard-apk

Darin liegt app-release.apk.
