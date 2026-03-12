import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Validators ---
  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите имя пользователя';
    }
    final v = value.trim();
    if (v.length < 3) return 'Минимум 3 символа';
    if (v.length > 30) return 'Максимум 30 символов';
    if (v.contains(' ')) return 'Пробелы запрещены';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
      return 'Только буквы, цифры и _';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите email';
    }
    final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Неверный формат email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (_isLogin) return null; // No strict validation on login
    if (value.length < 8) return 'Минимум 8 символов';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Нужна заглавная буква';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Нужна строчная буква';
    if (!RegExp(r'\d').hasMatch(value)) return 'Нужна хотя бы одна цифра';
    return null;
  }

  double _passwordStrength(String password) {
    if (password.isEmpty) return 0;
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'\d').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[!@#\$%\^&\*(),.?":{}|<>]').hasMatch(password)) {
      strength += 0.10;
    }
    return strength.clamp(0.0, 1.0);
  }

  Color _strengthColor(double strength) {
    if (strength < 0.3) return AppTheme.errorColor;
    if (strength < 0.6) return AppTheme.warningColor;
    if (strength < 0.9) return AppTheme.primaryColor;
    return AppTheme.successColor;
  }

  String _strengthLabel(double strength) {
    if (strength < 0.3) return 'Слабый';
    if (strength < 0.6) return 'Средний';
    if (strength < 0.9) return 'Хороший';
    return 'Отличный';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    if (_isLogin) {
      await ref
          .read(authProvider.notifier)
          .login(_usernameController.text.trim(), _passwordController.text);
    } else {
      await ref.read(authProvider.notifier).register(
            _usernameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final passwordStrength = _passwordStrength(_passwordController.text);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.secondaryColor
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Habit Tracker AI',
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Войди в аккаунт' : 'Создай аккаунт',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  // Error
                  if (authState.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.errorColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(authState.error!,
                                style: const TextStyle(
                                    color: AppTheme.errorColor, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                  // Username
                  TextFormField(
                    controller: _usernameController,
                    validator: _validateUsername,
                    autovalidateMode: _isLogin
                        ? AutovalidateMode.disabled
                        : AutovalidateMode.onUserInteraction,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Имя пользователя',
                      prefixIcon: const Icon(Icons.person_outline),
                      helperText: _isLogin ? null : 'Буквы, цифры и _ (3–30 символов)',
                      helperMaxLines: 1,
                    ),
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'example@mail.com',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    autovalidateMode: _isLogin
                        ? AutovalidateMode.disabled
                        : AutovalidateMode.onUserInteraction,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                  ),

                  // Password strength indicator (only for registration)
                  if (!_isLogin && _passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: passwordStrength,
                              backgroundColor: Colors.grey.shade200,
                              color: _strengthColor(passwordStrength),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _strengthLabel(passwordStrength),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _strengthColor(passwordStrength),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isLogin ? 'Войти' : 'Зарегистрироваться',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Google Sign-In
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _loading = true);
                              await ref
                                  .read(authProvider.notifier)
                                  .loginWithGoogle();
                              setState(() => _loading = false);
                            },
                      icon: const Text('G',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red)),
                      label: const Text('Войти через Google'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle
                  TextButton(
                    onPressed: () => setState(() {
                      _isLogin = !_isLogin;
                      _formKey.currentState?.reset();
                    }),
                    child: Text(
                      _isLogin
                          ? 'Нет аккаунта? Зарегистрируйся'
                          : 'Уже есть аккаунт? Войди',
                      style: const TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

