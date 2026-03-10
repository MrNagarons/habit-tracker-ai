import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/habit.dart';
import '../models/chat_message.dart';
import '../models/achievement.dart';
import '../models/friendship.dart';
import '../models/notification_item.dart';
import '../models/detailed_analytics.dart';

// ─── API Service singleton ───
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// ─── Auth state ───
enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  AuthState({this.status = AuthStatus.initial, this.user, this.error});

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  AuthNotifier(this._api) : super(AuthState());

  Future<void> checkAuth() async {
    await _api.loadToken();
    if (_api.isLoggedIn) {
      try {
        final user = await _api.getMe();
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } catch (_) {
        await _api.clearToken();
        state = AuthState(status: AuthStatus.unauthenticated);
      }
    } else {
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String username, String password) async {
    try {
      await _api.login(username, password);
      final user = await _api.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Неверный логин или пароль');
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // user cancelled

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        state = AuthState(
            status: AuthStatus.unauthenticated,
            error: 'Не удалось получить Google токен');
        return;
      }

      await _api.loginWithGoogle(idToken);
      final user = await _api.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Ошибка входа через Google');
    }
  }

  Future<void> register(
      String username, String email, String password) async {
    try {
      await _api.register(username, email, password);
      await login(username, password);
    } catch (e) {
      state = AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Ошибка регистрации. Попробуйте другое имя.');
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    try { await _googleSignIn.signOut(); } catch (_) {}
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return AuthNotifier(api);
});

// ─── Habits ───
class HabitsNotifier extends StateNotifier<AsyncValue<List<Habit>>> {
  final ApiService _api;

  HabitsNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> loadHabits() async {
    state = const AsyncValue.loading();
    try {
      final habits = await _api.getHabits();
      state = AsyncValue.data(habits);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createHabit(Map<String, dynamic> data) async {
    await _api.createHabit(data);
    await loadHabits();
  }

  Future<void> toggleHabit(int habitId, bool completed) async {
    await _api.logHabit(habitId, DateTime.now(), completed);
    await loadHabits();
  }

  Future<void> deleteHabit(int id) async {
    await _api.deleteHabit(id);
    await loadHabits();
  }
}

final habitsProvider =
    StateNotifierProvider<HabitsNotifier, AsyncValue<List<Habit>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return HabitsNotifier(api);
});

// ─── Analytics ───
final analyticsProvider = FutureProvider<Analytics>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getAnalytics();
});

// ─── Recommendations ───
final recommendationsProvider = FutureProvider<Recommendations>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getRecommendations();
});

// ─── Chat ───
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final ApiService _api;

  ChatNotifier(this._api) : super([]);

  Future<void> loadHistory() async {
    try {
      final messages = await _api.getChatHistory();
      state = messages;
    } catch (_) {}
  }

  Future<void> sendMessage(String content) async {
    // Add user message immediately
    state = [
      ...state,
      ChatMessage(role: 'user', content: content, timestamp: DateTime.now()),
    ];

    try {
      final response = await _api.sendChatMessage(content);
      state = [...state, response];
    } catch (e) {
      state = [
        ...state,
        ChatMessage(
          role: 'assistant',
          content: 'Извини, произошла ошибка. Попробуй ещё раз.',
          timestamp: DateTime.now(),
        ),
      ];
    }
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ChatNotifier(api);
});

// ─── Friends ───
class FriendsNotifier extends StateNotifier<AsyncValue<List<FriendInfo>>> {
  final ApiService _api;

  FriendsNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> loadFriends() async {
    state = const AsyncValue.loading();
    try {
      final friends = await _api.getFriends();
      state = AsyncValue.data(friends);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendRequest(int friendId) async {
    await _api.sendFriendRequest(friendId);
  }

  Future<void> acceptRequest(int friendshipId) async {
    await _api.acceptFriendRequest(friendshipId);
    await loadFriends();
  }

  Future<void> rejectRequest(int friendshipId) async {
    await _api.rejectFriendRequest(friendshipId);
  }

  Future<void> removeFriend(int friendId) async {
    await _api.removeFriend(friendId);
    await loadFriends();
  }
}

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, AsyncValue<List<FriendInfo>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return FriendsNotifier(api);
});

final friendRequestsProvider = FutureProvider<List<FriendInfo>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getFriendRequests();
});

// ─── Achievements ───
final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getAchievements();
});

// ─── Notifications ───
class NotificationsNotifier extends StateNotifier<AsyncValue<List<NotificationItem>>> {
  final ApiService _api;

  NotificationsNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> load() async {
    try {
      final items = await _api.getNotifications();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(int id) async {
    await _api.markNotificationRead(id);
    await load();
  }

  Future<void> markAllRead() async {
    await _api.markAllNotificationsRead();
    await load();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<List<NotificationItem>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return NotificationsNotifier(api);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getUnreadNotificationCount();
});

// ─── Detailed Analytics ───
final detailedAnalyticsProvider = FutureProvider<DetailedAnalytics>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getDetailedAnalytics();
});

