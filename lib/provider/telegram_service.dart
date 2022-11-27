import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dmdata_telegram_json/dmdata_telegram_json.dart';
import 'package:eqmonitor/env/env.dart';
import 'package:eqmonitor/provider/init/talker.dart';
import 'package:eqmonitor/utils/talker_log/log_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:talker_flutter/talker_flutter.dart';

final isSocketIoConnectedStateProvider = StateProvider<bool>((ref) => false);

/// SocketIOの接続を保持する
final telegramSocketIoProvider = Provider((ref) {
  final talker = ref.watch(talkerProvider);
  final key = Env.eqmonitorWebSocketUrl.split('=')[1];
  final socket = socket_io.io(
    'https://eqmonitor-db.yumnumm.net?apikey=f0d57694c49bba70037a50b0956b857e861edfad8ff4e18b4c263ce99548184ad6aa8fe3511fb98ca55f897865caf4927f770b60ad2190cac7c60e4534e16aad',
    //Env.eqmonitorWebSocketUrl,
    socket_io.OptionBuilder()
        .enableForceNew()
        .disableAutoConnect()
        .setPath('/dmdata/v1/socket.io')
        .setTransports(['websocket']).build(),
  )
    ..onConnecting((data) => talker.logTyped(SocketIOLog(data ?? '')))
    ..onConnect((data) {
      talker.logTyped(SocketIOLog(data ?? ''));
    })
    ..onAny(
      (event, data) => talker
          .logTyped(SocketIOLog('$event: $data'.replaceAll(key, '**KEY**'))),
    )
    ..onConnect(
      (data) =>
          ref.read(isSocketIoConnectedStateProvider.notifier).state = true,
    )
    ..onDisconnect(
      (data) =>
          ref.read(isSocketIoConnectedStateProvider.notifier).state = false,
    )
    ..connect();
  return socket;
});

final telegramStreamProvider = StreamProvider<WebSocketV2Data>((ref) async* {
  final socket = ref.watch(telegramSocketIoProvider);
  final stream = StreamController<dynamic>();
  final talker = ref.watch(talkerProvider);

  socket.on('data', stream.add);

  await for (final value in stream.stream) {
    try {
      final wsData = WebSocketV2Data.fromJson(value as Map<String, dynamic>);
      yield wsData;
    } catch (e, st) {
      talker.log(
        e,
        exception: e,
        stackTrace: st,
        logLevel: LogLevel.error,
      );
    }
  }
  ref.onDispose(stream.close);
});

final eewTelegramStreamProvider = StreamProvider<EewTelegram>((ref) async* {
  final stream = StreamController<EewTelegram>();
  final talker = ref.watch(talkerProvider);
  ref.watch(telegramStreamProvider).whenData(
    (value) {
      try {
        final telegram = TelegramJsonMain.fromJson(
          jsonDecode(
            utf8.decode(
              gzip.decode(
                base64.decode(value.body),
              ),
            ),
          ) as Map<String, dynamic>,
        );
        if (value.classification == 'eew.forecast') {
          final telegrams =
              EewTelegram(telegram, EewInformation.fromJson(telegram.body));
          stream.sink.add(telegrams);
        }
      } catch (e, st) {
        talker.log(
          e,
          exception: e,
          stackTrace: st,
          logLevel: LogLevel.error,
        );
      }
    },
  );
  ref.onDispose(stream.close);
});

@immutable
class EewTelegram {
  const EewTelegram(this.head, this.eew);

  final TelegramJsonMain head;
  final EewInformation eew;
}
