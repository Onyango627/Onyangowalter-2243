import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../routes.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// Screen 2 - Login (with a simple sign-up mode)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _hide = true;
  bool _remember = true;
  bool _signup = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _submit() {
    _authenticate();
  }

  Future<void> _authenticate() async {
    final state = context.read<AppState>();
    final email = _id.text.trim();
    final password = _pw.text;
    if (email.isEmpty ||
        password.isEmpty ||
        (_signup && _name.text.trim().isEmpty)) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_signup) {
      if (password.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters.');
        return;
      }
    }
    final ok = _signup
        ? await state.signUp(_name.text.trim(), email, password)
        : await state.login(email, password, remember: _remember);
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, Routes.home);
    } else {
      setState(
        () => _error = state.authError ?? 'Could not sign in. Try again.',
      );
    }
  }

  Future<void> _googleSignIn() async {
    final state = context.read<AppState>();
    final ok = await state.signInWithGoogle();
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, Routes.home);
    } else if (mounted && state.authError != null) {
      setState(() => _error = state.authError);
    }
  }

  Future<void> _forgotPassword() async {
    final email = TextEditingController(text: _id.text.trim());
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? error;
        bool sending = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Reset password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your account email and we’ll send you a reset link.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: email,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        final value = email.text.trim();
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(value)) {
                          setDialogState(
                            () => error = 'Enter a valid email address.',
                          );
                          return;
                        }
                        setDialogState(() {
                          sending = true;
                          error = null;
                        });
                        final sendError = await context
                            .read<AppState>()
                            .sendPasswordResetEmail(value);
                        if (!dialogContext.mounted) return;
                        if (sendError != null) {
                          setDialogState(() {
                            sending = false;
                            error = sendError;
                          });
                        } else {
                          Navigator.pop(
                            dialogContext,
                            'If an account exists for that email, a reset link has been sent.',
                          );
                        }
                      },
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send reset link'),
              ),
            ],
          ),
        );
      },
    );
    email.dispose();
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: simpleAppBar('', back: Navigator.canPop(context)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _signup ? 'Create account' : 'Login',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _signup
                    ? 'Set up your business account'
                    : 'Sign in to your account',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Email accounts can be created offline and stay on this device. Google sign-in needs internet.',
                style: TextStyle(
                  color: Colors.blueGrey.shade600,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (_signup) ...[
                TextField(
                  controller: _name,
                  decoration: _dec('Full name', Icons.person_outline),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _id,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Email', Icons.mail_outline),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _pw,
                obscureText: _hide,
                decoration: _dec(
                  'Password',
                  Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                      _hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
              if (!_signup)
                Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? true),
                    ),
                    const Text('Remember me', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    TextButton(
                      onPressed: _forgotPassword,
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(height: 14),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              PrimaryButton(
                label: _signup ? 'Sign Up' : 'Login',
                onPressed: _submit,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 18),
              _social(
                const _GoogleMark(),
                'Continue with Google',
                _googleSignIn,
              ),
              const SizedBox(height: 22),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _signup
                          ? 'Already have an account? '
                          : "Don't have an account? ",
                      style: const TextStyle(fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _signup = !_signup;
                        _error = null;
                      }),
                      child: Text(
                        _signup ? 'Login' : 'Sign Up',
                        style: TextStyle(
                          fontSize: 13,
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _social(Widget icon, String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label, style: const TextStyle(color: Colors.black87)),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CustomPaint(painter: _GoogleMarkPainter()),
  );
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.37;
    final stroke = size.width * 0.17;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        bounds,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Google's four-color G mark: blue right, green lower-right, yellow
    // lower-left, and red upper-left.
    const gap = 0.08;
    arc(const Color(0xFF4285F4), -math.pi / 4 + gap, math.pi / 2 - 2 * gap);
    arc(const Color(0xFF34A853), math.pi / 4 + gap, math.pi / 2 - 2 * gap);
    arc(const Color(0xFFFBBC05), 3 * math.pi / 4 + gap, math.pi / 2 - 2 * gap);
    arc(const Color(0xFFEA4335), 5 * math.pi / 4 + gap, math.pi / 2 - 2 * gap);
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - stroke / 2,
        center.dy - stroke / 2,
        radius + stroke,
        stroke,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
