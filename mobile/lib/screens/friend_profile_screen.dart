import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/friendship.dart';
import '../providers/app_providers.dart';

class FriendProfileScreen extends ConsumerStatefulWidget {
  final FriendInfo friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  ConsumerState<FriendProfileScreen> createState() =>
      _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  FriendProgress? _progress;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final api = ref.read(apiServiceProvider);
      final p = await api.getFriendProgress(widget.friend.userId);
      setState(() {
        _progress = p;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friend.username),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text('Ошибка: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadProgress();
                        },
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProgress,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Avatar & name
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: AppTheme.primaryColor,
                              backgroundImage: _progress?.avatarUrl != null
                                  ? NetworkImage(_progress!.avatarUrl!)
                                  : null,
                              child: _progress?.avatarUrl == null
                                  ? Text(
                                      widget.friend.username[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _progress?.username ?? widget.friend.username,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            if (widget.friend.createdAt != null)
                              Text(
                                'Друзья с ${_formatDate(widget.friend.createdAt!)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Stats grid
                      Row(
                        children: [
                          _StatTile(
                            icon: Icons.checklist,
                            label: 'Активных\nпривычек',
                            value: '${_progress?.activeHabits ?? 0}',
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          _StatTile(
                            icon: Icons.local_fire_department,
                            label: 'Лучшая\nсерия',
                            value: '${_progress?.bestStreak ?? 0} дн.',
                            color: AppTheme.warningColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatTile(
                            icon: Icons.pie_chart,
                            label: 'Общее\nвыполнение',
                            value:
                                '${_progress?.overallCompletionRate.toStringAsFixed(0) ?? 0}%',
                            color: AppTheme.successColor,
                          ),
                          const SizedBox(width: 12),
                          _StatTile(
                            icon: Icons.today,
                            label: 'Сегодня\nвыполнено',
                            value:
                                '${_progress?.todayCompleted ?? 0}/${_progress?.todayTotal ?? 0}',
                            color: AppTheme.secondaryColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Total habits
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.list_alt,
                                    color: AppTheme.primaryColor),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Всего привычек',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13)),
                                    Text(
                                      '${_progress?.totalHabits ?? 0}',
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Today's progress bar
                      if (_progress != null && _progress!.todayTotal > 0) ...[
                        const Text('Прогресс сегодня',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress!.todayTotal > 0
                                ? _progress!.todayCompleted /
                                    _progress!.todayTotal
                                : 0,
                            minHeight: 12,
                            backgroundColor:
                                AppTheme.primaryColor.withOpacity(0.1),
                            color: _progress!.todayCompleted ==
                                    _progress!.todayTotal
                                ? AppTheme.successColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_progress!.todayCompleted} из ${_progress!.todayTotal} выполнено',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

