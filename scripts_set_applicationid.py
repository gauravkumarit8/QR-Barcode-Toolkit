#!/usr/bin/env python3
"""
Sets applicationId (and namespace) to match the package name already
locked in on Play Console: com.grv.qr_barcode_toolkit
Run from the repo root, once, after `flutter create`.
"""
import os
import re
import sys

NEW_ID = "com.grv.qr_barcode_toolkit"

kts_path = "android/app/build.gradle.kts"
groovy_path = "android/app/build.gradle"

if os.path.exists(kts_path):
    path = kts_path
    pattern = re.compile(r'(applicationId\s*=\s*)"([^"]*)"')
    ns_pattern = re.compile(r'(namespace\s*=\s*)"([^"]*)"')
elif os.path.exists(groovy_path):
    path = groovy_path
    pattern = re.compile(r'(applicationId\s+)"([^"]*)"')
    ns_pattern = re.compile(r'(namespace\s+)"([^"]*)"')
else:
    print("ERROR: no android/app/build.gradle(.kts) found. Run `flutter create` first.")
    sys.exit(1)

s = open(path).read()
old_app_id = None
old_ns = None

m = pattern.search(s)
if m:
    old_app_id = m.group(2)
    s = pattern.sub(lambda m: f'{m.group(1)}"{NEW_ID}"', s, count=1)
else:
    print(f"WARNING: no applicationId line found in {path} — add it manually under defaultConfig.")

m2 = ns_pattern.search(s)
if m2:
    old_ns = m2.group(2)
    s = ns_pattern.sub(lambda m: f'{m.group(1)}"{NEW_ID}"', s, count=1)
else:
    print(f"NOTE: no namespace line found in {path} (fine on older Flutter templates).")

open(path, "w").write(s)

print(f"Updated {path}:")
if old_app_id:
    print(f"  applicationId: {old_app_id} -> {NEW_ID}")
if old_ns:
    print(f"  namespace:     {old_ns} -> {NEW_ID}")
print()
print("Also check (manually, if they exist) for any leftover references to the old ID:")
print("  grep -rn 'com.yourcompany' android/ 2>/dev/null")
