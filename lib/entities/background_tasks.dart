import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cake_wallet/core/sync_status_title.dart';
import 'package:cake_wallet/core/wallet_loading_service.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/feature_flag.dart';
import 'package:cake_wallet/view_model/settings/sync_mode.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_item.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_view_model.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cake_wallet/main.dart';
import 'package:cake_wallet/di.dart';
import 'package:intl/intl.dart';

const moneroSyncTaskKey = "com.fotolockr.cakewallet.monero_sync_task";
const mwebSyncTaskKey = "com.fotolockr.cakewallet.mweb_sync_task";

const initialNotificationTitle = 'Cake Background Sync';
const standbyMessage = 'On standby - app is in the foreground';
const readyMessage = 'Ready to sync - waiting until the app has been in the background for a while';

const notificationId = 888;
const notificationChannelId = 'cake_service';
const notificationChannelName = 'CAKE BACKGROUND SERVICE';
const notificationChannelDescription = 'Cake Wallet Background Service';
const DELAY_SECONDS_BEFORE_SYNC_START = 15;
const spNodeNotificationMessage =
    "Currently configured Bitcoin node does not support Silent Payments. skipping wallet";
const SYNC_THRESHOLD = 0.98;

void setMainNotification(
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin, {
  required String title,
  required String content,
}) async {
  flutterLocalNotificationsPlugin.show(
    notificationId,
    title,
    content,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        notificationChannelId,
        notificationChannelName,
        icon: 'ic_bg_service_small',
        ongoing: true,
        silent: true,
      ),
    ),
  );
}

void setNotificationStandby(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  flutterLocalNotificationsPlugin.cancelAll();
  setMainNotification(
    flutterLocalNotificationsPlugin,
    title: initialNotificationTitle,
    content: standbyMessage,
  );
}

void setNotificationReady(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  flutterLocalNotificationsPlugin.cancelAll();
  setMainNotification(
    flutterLocalNotificationsPlugin,
    title: initialNotificationTitle,
    content: readyMessage,
  );
}

void setWalletNotification(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
    {required String title, required String content, required int walletNum}) async {
  flutterLocalNotificationsPlugin.show(
    notificationId + walletNum,
    title,
    content,
    NotificationDetails(
      android: AndroidNotificationDetails(
        "${notificationChannelId}_$walletNum",
        "${notificationChannelName}_$walletNum",
        icon: 'ic_bg_service_small',
        ongoing: true,
        silent: true,
      ),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  print("BACKGROUND SERVICE STARTED");
  bool bgSyncStarted = false;
  Timer? _syncTimer;
  Timer? _queueTimer;

  // commented because the behavior appears to be bugged:
  // DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  service.on('stopService').listen((event) async {
    print("STOPPING BACKGROUND SERVICE");
    _syncTimer?.cancel();
    await service.stopSelf();
  });

  service.on('status').listen((event) async {
    print(event);
  });

  service.on('setForeground').listen((event) async {
    bgSyncStarted = false;
    _syncTimer?.cancel();
    setNotificationStandby(flutterLocalNotificationsPlugin);
  });

  service.on('setReady').listen((event) async {
    setNotificationReady(flutterLocalNotificationsPlugin);
  });

  // we have entered the background, start the sync:
  service.on('setBackground').listen((event) async {
    if (bgSyncStarted) {
      return;
    }
    bgSyncStarted = true;

    await Future.delayed(const Duration(seconds: DELAY_SECONDS_BEFORE_SYNC_START));
    print("STARTING SYNC FROM BG");

    try {
      await initializeAppConfigs(loadWallet: false);
    } catch (_) {
      // these errors still show up in logs which doesn't really make sense to me
    }

    print("INITIALIZED APP CONFIGS");

    // final currentWallet = getIt.get<AppStore>().wallet;
    // // don't start syncing immediately:
    // await currentWallet?.stopSync();

    final walletLoadingService = getIt.get<WalletLoadingService>();
    final settingsStore = getIt.get<SettingsStore>();
    final walletListViewModel = getIt.get<WalletListViewModel>();

    List<WalletBase> syncingWallets = [];
    List<WalletBase> standbyWallets = [];

    // get all Monero / Wownero wallets and add them
    final List<WalletListItem> moneroWallets = walletListViewModel.wallets
        .where((element) => [WalletType.monero, WalletType.wownero].contains(element.type))
        .toList();

    for (int i = 0; i < moneroWallets.length; i++) {
      final wallet = await walletLoadingService.load(moneroWallets[i].type, moneroWallets[i].name);
      final node = settingsStore.getCurrentNode(moneroWallets[i].type);
      await wallet.stopSync();
      syncingWallets.add(wallet);
    }

    // get all litecoin wallets and add them:
    final List<WalletListItem> litecoinWallets = walletListViewModel.wallets
        .where((element) => element.type == WalletType.litecoin)
        .toList();

    // we only need to sync the first litecoin wallet since they share the same collection of blocks
    if (litecoinWallets.isNotEmpty) {
      try {
        final firstWallet = litecoinWallets.first;
        final wallet = await walletLoadingService.load(firstWallet.type, firstWallet.name);
        await wallet.stopSync();
        syncingWallets.add(wallet);
      } catch (e) {
        // couldn't connect to mwebd (most likely)
        print("error syncing litecoin wallet: $e");
      }
    }

    // get all bitcoin wallets and add them:
    final List<WalletListItem> bitcoinWallets =
        walletListViewModel.wallets.where((element) => element.type == WalletType.bitcoin).toList();
    bool spSupported = true;
    for (int i = 0; i < bitcoinWallets.length; i++) {
      try {
        if (!spSupported) continue;
        final wallet =
            await walletLoadingService.load(bitcoinWallets[i].type, bitcoinWallets[i].name);
        final node = settingsStore.getCurrentNode(WalletType.bitcoin);
        await wallet.connectToNode(node: node);

        bool nodeSupportsSP = await (wallet as ElectrumWallet).getNodeSupportsSilentPayments();
        if (!nodeSupportsSP) {
          print("Configured node does not support silent payments, skipping wallet");
          setWalletNotification(
            flutterLocalNotificationsPlugin,
            title: initialNotificationTitle,
            content: spNodeNotificationMessage,
            walletNum: syncingWallets.length + 1,
          );
          spSupported = false;
          continue;
        }

        await wallet.stopSync();

        syncingWallets.add(wallet);
      } catch (e) {
        print("error syncing bitcoin wallet_$i: $e");
      }
    }

    print("STARTING SYNC TIMER");
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) async {
      for (int i = 0; i < syncingWallets.length; i++) {
        final wallet = syncingWallets[i];
        final syncStatus = wallet.syncStatus;
        final progress = wallet.syncStatus.progress();
        final progressPercent = (progress * 100).toStringAsPrecision(5) + "%";

        if (progress > 0.999) {
          print("WALLET $i SYNCED");
          wallet.stopSync();
          // pop the first wallet from the list
          standbyWallets.add(syncingWallets.removeAt(i));
          flutterLocalNotificationsPlugin.cancelAll();
          continue;
        }

        bool shouldSync = i == 0;
        String title = "${walletTypeToCryptoCurrency(wallet.type).title} - ${wallet.name}";
        late String content;

        if (shouldSync) {
          if (syncStatus is NotConnectedSyncStatus) {
            print("${wallet.name} NOT CONNECTED");
            final node = settingsStore.getCurrentNode(wallet.type);
            await wallet.connectToNode(node: node);
            wallet.startSync();
            print("STARTED SYNC");
            // wait a few seconds before checking progress
            // await Future.delayed(const Duration(seconds: 10));
          }

          if (syncStatus is SyncingSyncStatus) {
            final blocksLeft = syncStatus.blocksLeft;
            content = "$blocksLeft Blocks Left";
          } else if (syncStatus is SyncedSyncStatus) {
            content = "Synced";
          } else if (syncStatus is SyncedTipSyncStatus) {
            final tip = syncStatus.tip;
            content = "Scanned Tip: $tip";
          } else if (syncStatus is NotConnectedSyncStatus) {
            content = "Still Not Connected";
          } else if (syncStatus is AttemptingSyncStatus) {
            content = "Attempting Sync";
          } else if (syncStatus is StartingScanSyncStatus) {
            content = "Starting Scan";
          } else if (syncStatus is SyncronizingSyncStatus) {
            content = "Syncronizing";
          } else if (syncStatus is FailedSyncStatus) {
            content = "Failed Sync";
          } else if (syncStatus is ConnectingSyncStatus) {
            content = "Connecting";
          } else {
            throw Exception("sync type not covered");
          }
        } else {
          if (syncStatus is! NotConnectedSyncStatus) {
            wallet.stopSync();
          }
          if (progress < SYNC_THRESHOLD) {
            content = "$progressPercent - Waiting in sync queue";
          } else {
            content = "$progressPercent - This shouldn't happen, wallet is > SYNC_THRESHOLD";
          }
        }

        content += " - ${DateFormat("hh:mm:ss").format(DateTime.now())}";

        setWalletNotification(
          flutterLocalNotificationsPlugin,
          title: title,
          content: content,
          walletNum: i,
        );
      }

      for (int i = 0; i < standbyWallets.length; i++) {
        int notificationIndex = syncingWallets.length + i + 1;
        final wallet = standbyWallets[i];
        final title = "${walletTypeToCryptoCurrency(wallet.type).title} - ${wallet.name}";
        String content = "Synced - on standby until next queue refresh";

        setWalletNotification(
          flutterLocalNotificationsPlugin,
          title: title,
          content: content,
          walletNum: notificationIndex,
        );
      }
    });

    _queueTimer?.cancel();
    // add a timer that checks all wallets and adds them to the queue if they are less than SYNC_THRESHOLD synced:
    _queueTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      for (int i = 0; i < standbyWallets.length; i++) {
        final wallet = standbyWallets[i];
        final syncStatus = wallet.syncStatus;
        // connect to the node if we haven't already:
        if (syncStatus is NotConnectedSyncStatus) {
          final node = settingsStore.getCurrentNode(wallet.type);
          await wallet.connectToNode(node: node);
          await wallet.startSync();
          await Future.delayed(
              const Duration(seconds: 10)); // wait a few seconds before checking progress
        }

        if (syncStatus.progress() < SYNC_THRESHOLD) {
          syncingWallets.add(standbyWallets.removeAt(i));
        }
      }
    });
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}

Future<void> initializeService(FlutterBackgroundService bgService, bool useNotifications) async {
  if (useNotifications) {
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('ic_bg_service_small'),
        ),
      );
    }

    for (int i = 0; i < 10; i++) {
      AndroidNotificationChannel channel = AndroidNotificationChannel(
        "${notificationChannelId}_$i",
        "${notificationChannelName}_$i",
        description: notificationChannelDescription,
        importance: Importance.min,
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    setNotificationStandby(flutterLocalNotificationsPlugin);
  }

  // notify the service that we are in the foreground:
  bgService.invoke("setForeground");

  try {
    bool isServiceRunning = await bgService.isRunning();
    if (isServiceRunning) {
      print("Service is ALREADY running!");
      return;
    }
  } catch (_) {}

  print("INITIALIZING SERVICE");

  await bgService.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: initialNotificationTitle,
      initialNotificationContent: standbyMessage,
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

class BackgroundTasks {
  FlutterBackgroundService bgService = FlutterBackgroundService();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  void serviceBackground() {
    bgService.invoke("setBackground");
  }

  Future<void> serviceForeground() async {
    final settingsStore = getIt.get<SettingsStore>();
    bool showNotifications = settingsStore.showSyncNotification;
    bgService.invoke('stopService');
    await Future.delayed(const Duration(seconds: 2));
    initializeService(bgService, showNotifications);
  }

  void serviceReady() {
    final settingsStore = getIt.get<SettingsStore>();
    bool showNotifications = settingsStore.showSyncNotification;
    if (showNotifications) {
      bgService.invoke('setReady');
    }
  }

  void registerBackgroundService() async {
    print("REGISTER BACKGROUND SERVICE");
    try {
      final settingsStore = getIt.get<SettingsStore>();
      final walletListViewModel = getIt.get<WalletListViewModel>();
      bool hasMonero =
          walletListViewModel.wallets.any((element) => element.type == WalletType.monero);

      bool hasLitecoin =
          walletListViewModel.wallets.any((element) => element.type == WalletType.litecoin);

      bool hasBitcoin =
          walletListViewModel.wallets.any((element) => element.type == WalletType.bitcoin);

      if (!settingsStore.silentPaymentsAlwaysScan) {
        hasBitcoin = false;
      }
      if (!settingsStore.mwebAlwaysScan) {
        hasLitecoin = false;
      }

      /// if its not android nor ios, or the user has no monero wallets; exit
      if (!DeviceInfo.instance.isMobile || (!hasMonero && !hasLitecoin && !hasBitcoin)) {
        return;
      }

      final SyncMode syncMode = settingsStore.currentSyncMode;
      final bool useNotifications = settingsStore.showSyncNotification;

      if (useNotifications) {
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      bgService.invoke("stopService");

      if (syncMode.type == SyncType.disabled || !FeatureFlag.isBackgroundSyncEnabled) {
        return;
      }

      await initializeService(bgService, useNotifications);
    } catch (error, stackTrace) {
      print(error);
      print(stackTrace);
    }
  }
}
