# SHREEJI AUTOLINK – Quotation Maker (offline Android app)

Flutter + SQLite. No internet, no cloud, no login. All data stays in the phone's private app storage.

## APK kevi rite banavvo

### Option 1 – GitHub (computer ma kai install karvu nathi)
1. github.com par free account -> New repository (Private) banavo.
2. Aa folder ni badhi files upload karo (lib, assets, pubspec.yaml, setup.sh, .github, README.md).
3. "Actions" tab -> "Build Android APK" -> Run workflow (athva upload pachhi automatic chale).
4. 6-10 minute pachhi run ma "Shreeji-Autolink-APK" artifact download karo -> zip ma `app-release.apk`.

### Option 2 – Potana computer par
1. Flutter SDK + Android Studio (Android SDK) install karo, `flutter doctor` OK hovu joie.
2. Folder ma terminal kholo:  `bash setup.sh`  (Windows: Git Bash / WSL)
3. `flutter build apk --release`
4. APK: `build/app/outputs/flutter-apk/app-release.apk`

## Phone ma install
APK phone ma copy/WhatsApp karo -> open -> "Install unknown apps" allow karo -> Install.

## Backup & Restore
- Home -> BACKUP & RESTORE -> CREATE BACKUP NOW: file `shreeji_backup_YYYYMMDD_HHMMSS.json` app ma pan save thay chhe ane phone storage (Downloads/Documents) ma save karva no dialog aave chhe. Share button thi Google Drive/WhatsApp par pan mokli shako.
- Restore: RESTORE FROM FILE -> backup .json select karo. Restore pehla current data nu safety backup automatic bane chhe.
- Backup ma: customers, quotations + badha revisions, vehicle master, company/bank settings, terms, price master. (PIN backup ma nathi.)
- Phone badalo to: new phone ma app install -> RESTORE FROM FILE.
