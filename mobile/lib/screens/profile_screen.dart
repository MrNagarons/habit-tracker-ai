import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  bool _saving = false;
  String? _error;
  bool _hasChanges = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');

    _usernameController.addListener(_onChanged);
    _emailController.addListener(_onChanged);
  }

  void _onChanged() {
    final user = ref.read(authProvider).user;
    setState(() {
      _hasChanges = _usernameController.text != (user?.username ?? '') ||
          _emailController.text != (user?.email ?? '');
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Выбрать фото',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Камера'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.secondaryColor,
                  child: const Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Галерея'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.uploadAvatar(File(picked.path));
      await ref.read(authProvider.notifier).checkAuth();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Аватар обновлён ✅'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
    setState(() => _uploadingAvatar = false);
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сменить пароль'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Текущий пароль',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Введите текущий пароль' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Новый пароль',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите новый пароль';
                  if (v.length < 8) return 'Минимум 8 символов';
                  if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Нужна заглавная буква';
                  if (!RegExp(r'[a-z]').hasMatch(v)) return 'Нужна строчная буква';
                  if (!RegExp(r'\d').hasMatch(v)) return 'Нужна цифра';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Подтвердите пароль',
                  prefixIcon: Icon(Icons.lock_clock),
                ),
                validator: (v) {
                  if (v != newPwdCtrl.text) return 'Пароли не совпадают';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final api = ref.read(apiServiceProvider);
                await api.changePassword(
                    currentPwdCtrl.text, newPwdCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Пароль изменён ✅'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Сменить'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateProfile({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
      });

      ref.read(authProvider.notifier).checkAuth();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Профиль обновлён ✅'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сохранить',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar with upload button
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: user?.avatarUrl != null
                      ? NetworkImage(user!.avatarUrl!)
                      : null,
                  child: _uploadingAvatar
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3)
                      : user?.avatarUrl == null
                          ? Text(
                              user?.username.substring(0, 1).toUpperCase() ??
                                  '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Зарегистрирован: ${_formatDate(user?.createdAt)}',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 28),

          // Error
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error!,
                  style: const TextStyle(color: AppTheme.errorColor)),
            ),

          // Username
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Имя пользователя',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),

          // Email
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 32),

          // Save button
          if (_hasChanges)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Сохранить изменения',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          const SizedBox(height: 16),

          // Change password button
          OutlinedButton.icon(
            onPressed: _showChangePasswordDialog,
            icon: const Icon(Icons.lock_reset),
            label: const Text('Сменить пароль'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
