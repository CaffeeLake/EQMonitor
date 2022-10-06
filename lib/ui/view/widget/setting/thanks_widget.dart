import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ThanksWidget extends StatelessWidget {
  const ThanksWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const titleTextStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    return ExpansionTile(
      title: const Text('Special Thanks', style: titleTextStyle),
      leading: const Icon(Icons.favorite),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            color: t.colorScheme.secondaryContainer.withOpacity(0.4),
            elevation: 0,
            child: Column(
              children: const [
                ThanksItem(
                  title: 'Project DM-D.S.S',
                  description: '緊急地震速報等の地震情報',
                  url: 'https://dmdata.jp/',
                ),
                ThanksItem(
                  title: 'François LN / フランソワ (JQuake)氏',
                  description: '強震モニタ画像解析手法',
                  url: 'https://qiita.com/NoneType1/items/a4d2cf932e20b56ca444',
                ),
                ThanksItem(
                  title: '国立研究開発法人 防災科学技術研究所',
                  description: 'リアルタイム震度データ',
                  url:
                      'https://www.kyoshin.bosai.go.jp/kyoshin/docs/new_kyoshinmonitor.html',
                ),
                ThanksItem(
                  title: '国土交通省 気象庁',
                  description: '地図データ',
                  url: 'https://www.jma.go.jp/jma/kishou/info/coment.html',
                ),
                ThanksItem(
                  title: 'および 全ての関係者に感謝いたします。',
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}

class ThanksItem extends StatelessWidget {
  const ThanksItem({
    this.icon,
    required this.title,
    this.description,
    this.url,
    super.key,
  });

  final Widget? icon;
  final String title;
  final String? description;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 48,
        child: Center(
          child: icon,
        ),
      ),
      title: Text(
        title,
        style: t.textTheme.bodyMedium!.copyWith(
          color: t.colorScheme.onSecondaryContainer,
        ),
      ),
      subtitle: description != null
          ? Text(
              description!,
              style: t.textTheme.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : null,
      onTap: () => url != null
          ? launchUrl(
              Uri.parse(url!),
              mode: LaunchMode.externalApplication,
            )
          : null,
    );
  }
}
