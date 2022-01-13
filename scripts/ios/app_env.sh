#!/bin/sh

APP_IOS_NAME=""
APP_IOS_VERSION=""
APP_IOS_BUILD_VERSION=""
APP_IOS_BUNDLE_ID=""

MONERO_COM="monero.com"
CAKEWALLET="cakewallet"

TYPES=($MONERO_COM $CAKEWALLET)
APP_IOS_TYPE=$1

MONERO_COM_NAME="Monero.com"
MONERO_COM_VERSION="1.0.1"
MONERO_COM_BUILD_NUMBER=6
MONERO_COM_BUNDLE_ID="com.cakewallet.monero"

CAKEWALLET_NAME="Cake Wallet"
CAKEWALLET_VERSION="4.3.0"
CAKEWALLET_BUILD_NUMBER=71
CAKEWALLET_BUNDLE_ID="com.fotolockr.cakewallet"

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
esac

export APP_IOS_TYPE
export APP_IOS_NAME
export APP_IOS_VERSION
export APP_IOS_BUILD_NUMBER
export APP_IOS_BUNDLE_ID
