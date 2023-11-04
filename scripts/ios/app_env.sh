#!/bin/sh

APP_IOS_NAME=""
APP_IOS_VERSION=""
APP_IOS_BUILD_VERSION=""
APP_IOS_BUNDLE_ID=""

MONERO_COM="monero.com"
CAKEWALLET="cakewallet"
HAVEN="haven"

TYPES=($MONERO_COM $CAKEWALLET $HAVEN)
APP_IOS_TYPE=$1

MONERO_COM_NAME="Monero.com"
MONERO_COM_VERSION="1.7.4"
MONERO_COM_BUILD_NUMBER=63
MONERO_COM_BUNDLE_ID="com.cakewallet.monero"

CAKEWALLET_NAME="Cake Wallet"
CAKEWALLET_VERSION="4.10.4"
CAKEWALLET_BUILD_NUMBER=196
CAKEWALLET_BUNDLE_ID="com.fotolockr.cakewallet"

HAVEN_NAME="Haven"
HAVEN_VERSION="1.0.0"
HAVEN_BUILD_NUMBER=3
HAVEN_BUNDLE_ID="com.cakewallet.haven"

if ! [[ " ${TYPES[*]} " =~ " ${APP_IOS_TYPE} " ]]; then
    echo "Wrong app type."
    exit 1
fi

case $APP_IOS_TYPE in
	$MONERO_COM)
		APP_IOS_NAME=$MONERO_COM_NAME
		APP_IOS_VERSION=$MONERO_COM_VERSION
		APP_IOS_BUILD_NUMBER=$MONERO_COM_BUILD_NUMBER
		APP_IOS_BUNDLE_ID=$MONERO_COM_BUNDLE_ID
		;;
	$CAKEWALLET)
		APP_IOS_NAME=$CAKEWALLET_NAME
		APP_IOS_VERSION=$CAKEWALLET_VERSION
		APP_IOS_BUILD_NUMBER=$CAKEWALLET_BUILD_NUMBER
		APP_IOS_BUNDLE_ID=$CAKEWALLET_BUNDLE_ID
		;;
	$HAVEN)
		APP_IOS_NAME=$HAVEN_NAME
		APP_IOS_VERSION=$HAVEN_VERSION
		APP_IOS_BUILD_NUMBER=$HAVEN_BUILD_NUMBER
		APP_IOS_BUNDLE_ID=$HAVEN_BUNDLE_ID
		;;
esac

export APP_IOS_TYPE
export APP_IOS_NAME
export APP_IOS_VERSION
export APP_IOS_BUILD_NUMBER
export APP_IOS_BUNDLE_ID
