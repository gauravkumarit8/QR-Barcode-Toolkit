#!/usr/bin/env python3
"""
One-time helper: wires release signing into whichever gradle file
`flutter create` generated (build.gradle.kts or build.gradle), without
needing you to know/guess which format your Flutter version uses.

Run AFTER you've generated the upload keystore (see RELEASE_SIGNING.md
step 1). Does NOT create the keystore itself and does NOT touch secrets —
it only adds the plumbing that reads key.properties, which you create
separately and which .gitignore already excludes.
"""
import os
import sys

kts_path = "android/app/build.gradle.kts"
groovy_path = "android/app/build.gradle"

KTS_HEADER = '''import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

'''

KTS_SIGNING_CONFIG = '''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
'''

GROOVY_HEADER = '''def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

'''

GROOVY_SIGNING_CONFIG = '''    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
'''


def patch_kts():
    s = open(kts_path).read()
    if "keystoreProperties" in s:
        print(f"{kts_path} already patched — skipping.")
        return True
    s = KTS_HEADER + s
    if "signingConfigs" in s:
        print(f"WARNING: {kts_path} already has a signingConfigs block — "
              "edit it manually to use keystoreProperties instead of auto-patching.")
        open(kts_path, "w").write(s)  # still add the header so properties load
        return True
    if "buildTypes {" in s:
        s = s.replace("buildTypes {", KTS_SIGNING_CONFIG + "\n    buildTypes {", 1)
        s = s.replace(
            'release {',
            'release {\n            signingConfig = signingConfigs.getByName("release")',
            1,
        )
    else:
        print(f"Could not find 'buildTypes {{' in {kts_path} — add the signing "
              "block manually using RELEASE_SIGNING.md.")
        return False
    open(kts_path, "w").write(s)
    print(f"Patched {kts_path}")
    return True


def patch_groovy():
    s = open(groovy_path).read()
    if "keystoreProperties" in s:
        print(f"{groovy_path} already patched — skipping.")
        return True
    s = GROOVY_HEADER + s
    if "android {" in s:
        s = s.replace("android {", "android {\n" + GROOVY_SIGNING_CONFIG, 1)
    else:
        print(f"Could not find 'android {{' in {groovy_path} — add manually.")
        return False
    if "buildTypes {" in s and "release {" in s:
        s = s.replace("release {", "release {\n            signingConfig signingConfigs.release", 1)
    open(groovy_path, "w").write(s)
    print(f"Patched {groovy_path}")
    return True


if os.path.exists(kts_path):
    ok = patch_kts()
elif os.path.exists(groovy_path):
    ok = patch_groovy()
else:
    print("ERROR: neither build.gradle.kts nor build.gradle found at expected path.")
    print("Run this from your repo root, after `flutter create` has run.")
    sys.exit(1)

print()
print("Next: create android/key.properties (gitignored) with:")
print("  storePassword=<your keystore password>")
print("  keyPassword=<your key password>")
print("  keyAlias=upload")
print("  storeFile=<path to your .jks, e.g. /home/user/upload-keystore.jks>")
print()
print("Then: flutter build appbundle --release")
sys.exit(0 if ok else 1)
