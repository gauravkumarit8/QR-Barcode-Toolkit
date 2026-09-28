# Release signing (needed before the first Play upload)

Play needs a signed **.aab**. You sign with an *upload key*; with Play App
Signing (default for new apps) Google holds the real app-signing key, so if you
ever lose the upload key, Play support can reset it. Still: back it up.

## 1. Create the upload keystore (once, on your machine)
Needs `keytool` (ships with any JDK). No JDK on Windows? Either
`winget install EclipseAdoptium.Temurin.17.JDK` or use Android Studio's bundled
`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`.

```powershell
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Save it OUTSIDE the repo (e.g. a password manager attachment + an offline copy).
Write down: keystore password, key password, alias (`upload`).
`.gitignore` already blocks `*.jks`, `*.keystore` and `android/key.properties`.
NEVER commit them or paste passwords in chat/issues.

## 2. Tell gradle to use it
After `flutter create`, edit `android/app/build.gradle.kts` (new Flutter
templates) or `android/app/build.gradle` (older). Add the block for your format.

### Kotlin DSL (`build.gradle.kts`)
At the very top of the file:
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```
Inside `android { ... }`:
```kotlin
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
```
(If a `buildTypes { release { ... } }` block already exists, just change its
`signingConfig` line instead of adding a second block.)

### Groovy (`build.gradle`)
Above `android {`:
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```
Inside `android { ... }`:
```groovy
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
```

## 3. Local signed build (optional)
Create `android/key.properties` (gitignored):
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```
and copy the keystore to `android/app/upload-keystore.jks`, then
`flutter build appbundle --release`.

## 4. CI signed build (GitHub Actions)
Add 4 repository secrets: repo → Settings → Secrets and variables → Actions.

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64 of the .jks (command below) |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_KEY_ALIAS` | `upload` |

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```
Then paste from the clipboard into the first secret.

Trigger a release build: either Actions tab → Build → **Run workflow**, or
```powershell
git tag v0.1.0
git push --tags
```
Download the `release-aab` artifact and upload it to Play Console (Internal
testing first). Pushes to `main` still build an unsigned-secrets-free debug APK.

## Note on the debug/release split
Push builds are now `--debug` on purpose: once `signingConfig` points at
`key.properties`, a plain `flutter build apk --release` fails without secrets.
