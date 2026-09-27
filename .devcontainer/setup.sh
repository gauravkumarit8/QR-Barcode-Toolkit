#!/bin/bash
set -e

# Install Flutter (pinned to stable channel)
git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> $HOME/.bashrc
export PATH="$HOME/flutter/bin:$PATH"

# Install Android cmdline-tools
mkdir -p $HOME/android-sdk/cmdline-tools
cd $HOME/android-sdk/cmdline-tools
curl -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q cmdline-tools.zip
mv cmdline-tools latest
rm cmdline-tools.zip
echo 'export ANDROID_HOME=$HOME/android-sdk' >> $HOME/.bashrc
echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"' >> $HOME/.bashrc
export ANDROID_HOME=$HOME/android-sdk
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

yes | sdkmanager --licenses > /dev/null
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

flutter config --android-sdk $ANDROID_HOME
flutter doctor
