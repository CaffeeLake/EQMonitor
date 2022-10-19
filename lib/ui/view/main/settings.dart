import 'package:eqmonitor/provider/setting/developer_mode.dart';
import 'package:eqmonitor/ui/view/setting/component/setting_section.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const descriptionTextStyle = TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 14,
    );
    const titleTextStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SettingsSection(
              title: null,
              children: <Widget>[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: const Icon(Icons.notifications),
                  title: const Text(
                    '通知設定',
                    style: titleTextStyle,
                  ),
                  subtitle: const Text(
                    '通知の条件設定などを行うことができます',
                    style: descriptionTextStyle,
                  ),
                  onTap: () => context.push('/settings/notification'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: const Icon(Icons.design_services),
                  title: const Text(
                    'デザイン設定',
                    style: titleTextStyle,
                  ),
                  subtitle: const Text(
                    'テーマや配色を選択できます',
                    style: descriptionTextStyle,
                  ),
                  onTap: () => context.push('/settings/design'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: const Icon(Icons.info),
                  title: const Text(
                    '本アプリについて',
                    style: titleTextStyle,
                  ),
                  subtitle: const Text(
                    'ライセンスやアプリの情報を確認できます',
                    style: descriptionTextStyle,
                  ),
                  onTap: () => context.push('/settings/appinfo'),
                ),
                if (kDebugMode ||
                    ref.watch(developerModeProvider).isDeveloper) ...[
                  const Divider(),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: const Icon(Icons.bug_report),
                    title: const Text(
                      'デバッグメニュー',
                      style: titleTextStyle,
                    ),
                    subtitle: const Text(
                      'WebSocketのステータスやEEWのテストを行えます',
                      style: descriptionTextStyle,
                    ),
                    onTap: () => context.push('/settings/debug'),
                  )
                ],
              ]
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: e,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
      // body: SettingsList(
      //   sections: [
      //     SettingsSection(
      //       tiles: <SettingsTile>[
      //         SettingsTile.navigation(
      //           leading: const Icon(Icons.notifications),
      //           title: const Text('通知設定'),
      //           onPressed: (context) => context.push('/settings/notification'),
      //         ),
      //         SettingsTile.navigation(
      //           leading: const Icon(Icons.design_services),
      //           title: const Text('デザイン設定'),
      //           onPressed: (context) => context.push('/settings/design'),
      //         ),
      //         SettingsTile.navigation(
      //           leading: const Icon(Icons.info),
      //           title: const Text('本アプリについて'),
      //           onPressed: (context) => context.push('/settings/appinfo'),
      //         ),
      //         if (kDebugMode || ref.watch(developerModeProvider).isDeveloper)
      //           SettingsTile.navigation(
      //             leading: const Icon(Icons.bug_report),
      //             title: const Text('デバッグメニュー'),
      //             onPressed: (context) => context.push('/settings/debug'),
      //           ),
      //       ],
      //     ),
      //   ],
      // ),
    );
  }
}
