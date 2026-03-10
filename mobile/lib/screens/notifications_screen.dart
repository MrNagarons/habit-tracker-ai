import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsProvider.notifier).markAllRead();
              ref.invalidate(unreadCountProvider);
            },
            child: const Text('Прочитать все',
                style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64,
                      color: AppTheme.textSecondary),
                  SizedBox(height: 16),
                  Text('Нет уведомлений',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsProvider.notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: notifications.length,
              itemBuilder: (ctx, i) {
                final n = notifications[i];
                return Card(
                  color: n.isRead
                      ? AppTheme.surfaceColor
                      : AppTheme.primaryColor.withOpacity(0.05),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getTypeColor(n.type).withOpacity(0.15),
                      child: Icon(_getTypeIcon(n.type),
                          color: _getTypeColor(n.type), size: 20),
                    ),
                    title: Text(n.title,
                        style: TextStyle(
                          fontWeight:
                              n.isRead ? FontWeight.normal : FontWeight.w600,
                          fontSize: 14,
                        )),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (n.body.isNotEmpty)
                          Text(n.body,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2),
                        Text(
                          _timeAgo(n.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    trailing: !n.isRead
                        ? GestureDetector(
                            onTap: () async {
                              await ref
                                  .read(notificationsProvider.notifier)
                                  .markRead(n.id);
                              ref.invalidate(unreadCountProvider);
                            },
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                    isThreeLine: n.body.isNotEmpty,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'achievement':
        return Icons.emoji_events;
      case 'friend_request':
        return Icons.person_add;
      case 'friend_accepted':
        return Icons.people;
      case 'reminder':
        return Icons.alarm;
      case 'evening_reminder':
        return Icons.nightlight;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'achievement':
        return Colors.amber;
      case 'friend_request':
      case 'friend_accepted':
        return AppTheme.primaryColor;
      case 'reminder':
      case 'evening_reminder':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
  }
}

