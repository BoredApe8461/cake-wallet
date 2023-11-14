#!/bin/bash

CAKEWALLET="cakewallet"
DIR=`pwd`

if [ -z "$APP_LINUX_TYPE" ]; then
        echo "Please set APP_LINUX_TYPE"
        exit 1
fi

../android/app_properties.sh
../android/app_icon.sh
../android/manifest.sh
../android/inject_app_details.sh

cd ../.. # go to root
CONFIG_ARGS=""

case $APP_LINUX_TYPE in
        $CAKEWALLET)
		CONFIG_ARGS="--monero --bitcoin --ethereum --nano --excludeFlutterSecureStorage";;
esac

cp -rf pubspec_description.yaml pubspec.yaml
flutter pub get
dart run tool/generate_pubspec.dart
flutter pub get
dart run tool/configure.dart $CONFIG_ARGS
sed -i '0,/version: 0.0.0/s//version: '"${APP_LINUX_VERSION}"'+'"${APP_LINUX_BUILD_NUMBER}"'/' pubspec.yaml
cd $DIR
