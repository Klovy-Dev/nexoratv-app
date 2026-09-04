import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/channel.dart';
import '../../state/epg_provider.dart';

class ChannelTile extends ConsumerWidget {
  const ChannelTile({
    super.key,
    required this.channel,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
    this.showFavorite = true,
  });

  final Channel channel;
  final bool isFavorite;
  final bool showFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? subtitle = channel.group;
    if (channel.isLive) {
      final guide = ref.watch(epgGuideProvider).value;
      if (guide != null) {
        final now = nowOn(epgForChannel(guide, channel));
        if (now != null) subtitle = '▶ ${now.title}';
      }
    }

    return ListTile(
      onTap: onTap,
      leading: SizedBox(width: 40, height: 40, child: _Logo(url: channel.logo)),
      title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: showFavorite
          ? IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : null,
              ),
              onPressed: onToggleFavorite,
            )
          : const Icon(Icons.chevron_right),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.live_tv, size: 22);
    if (url == null) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.contain,
      memCacheWidth: 96,
      fadeInDuration: const Duration(milliseconds: 120),
      errorWidget: (_, _, _) => fallback,
      placeholder: (_, _) => const Icon(Icons.live_tv_outlined, size: 22),
    );
  }
}
