#!/bin/bash

APP_ANDROID_NAME=""
APP_ANDROID_VERSION=""
APP_ANDROID_BUILD_VERSION=""
APP_ANDROID_ID=""
APP_ANDROID_PACKAGE=""
APP_ANDROID_SCHEME=""

MONERO_COM="monero.com"
CAKEWALLET="cakewallet"
HAVEN="haven"

TYPES=($MONERO_COM $CAKEWALLET $HAVEN)
APP_ANDROID_TYPE=$1

MONERO_COM_NAME="Monero.com"
MONERO_COM_VERSION="1.12.0"
MONERO_COM_BUILD_NUMBER=79
MONERO_COM_BUNDLE_ID="com.monero.app"
MONERO_COM_PACKAGE="com.monero.app"
MONERO_COM_SCHEME="monero.com"

CAKEWALLET_NAME="Cake Wallet"
CAKEWALLET_VERSION="4.15.2"
CAKEWALLET_BUILD_NUMBER=200
CAKEWALLET_BUNDLE_ID="com.cakewallet.cake_wallet"
CAKEWALLET_PACKAGE="com.cakewallet.cake_wallet"
CAKEWALLET_SCHEME="cakewallet"

HAVEN_NAME="Haven"
HAVEN_VERSION="1.0.0"
HAVEN_BUILD_NUMBER=1
HAVEN_BUNDLE_ID="com.cakewallet.haven"
HAVEN_PACKAGE="com.cakewallet.haven"

if ! [[ " ${TYPES[*]} " =~ " ${APP_ANDROID_TYPE} " ]]; then
    echo "Wrong app type."
    return 1 2>/dev/null
    exit 1
fi

case $APP_ANDROID_TYPE in
	$MONERO_COM)
		APP_ANDROID_NAME=$MONERO_COM_NAME
		APP_ANDROID_VERSION=$MONERO_COM_VERSION
		APP_ANDROID_BUILD_NUMBER=$MONERO_COM_BUILD_NUMBER
		APP_ANDROID_BUNDLE_ID=$MONERO_COM_BUNDLE_ID
		APP_ANDROID_PACKAGE=$MONERO_COM_PACKAGE
		APP_ANDROID_SCHEME=$MONERO_COM_SCHEME
		;;
	$CAKEWALLET)
		APP_ANDROID_NAME=$CAKEWALLET_NAME
		APP_ANDROID_VERSION=$CAKEWALLET_VERSION
		APP_ANDROID_BUILD_NUMBER=$CAKEWALLET_BUILD_NUMBER
		APP_ANDROID_BUNDLE_ID=$CAKEWALLET_BUNDLE_ID
		APP_ANDROID_PACKAGE=$CAKEWALLET_PACKAGE
		APP_ANDROID_SCHEME=$CAKEWALLET_SCHEME
		;;
	$HAVEN)
		APP_ANDROID_NAME=$HAVEN_NAME
		APP_ANDROID_VERSION=$HAVEN_VERSION
		APP_ANDROID_BUILD_NUMBER=$HAVEN_BUILD_NUMBER
		APP_ANDROID_BUNDLE_ID=$HAVEN_BUNDLE_ID
		APP_ANDROID_PACKAGE=$HAVEN_PACKAGE
		;;
esac

export APP_ANDROID_TYPE
export APP_ANDROID_NAME
export APP_ANDROID_VERSION
export APP_ANDROID_BUILD_NUMBER
export APP_ANDROID_BUNDLE_ID
export APP_ANDROID_PACKAGE
export APP_ANDROID_SCHEME