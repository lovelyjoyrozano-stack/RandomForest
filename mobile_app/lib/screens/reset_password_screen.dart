import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String initialToken;
  const ResetPasswordScreen({super.key, this.initialToken = ''});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}
class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true, _hideConfirm = true, _loading = false;
  String? _error;
  @override
  void initState() { super.initState(); _token.text = widget.initialToken; }
  @override
  void dispose() { _token.dispose(); _password.dispose(); _confirm.dispose(); super.dispose(); }
  bool get _strong {
    final p = _password.text;
    return p.length >= 8 && RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[0-9]').hasMatch(p) && RegExp(r'[^A-Za-z0-9]').hasMatch(p);
  }
  Future<void> _submit() async {
    if (!_strong) { setState(() => _error = 'Password must be 8+ characters and include uppercase, lowercase, number, and special character.'); return; }
    if (_password.text != _confirm.text) { setState(() => _error = 'Passwords do not match.'); return; }
    if (_token.text.trim().isEmpty) { setState(() => _error = 'Reset token is missing. Open the link from your email.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiClient.instance.post('/password/reset', auth: false, body: {'token': _token.text.trim(), 'password': _password.text});
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Password updated'), content: Text((result as Map)['message']?.toString() ?? 'Password updated successfully.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    } on ApiException catch (e) { if (mounted) setState(() => _error = e.message); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset Password')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.password, size: 52, color: primaryGreen),
        const SizedBox(height: 16),
        TextField(controller: _token, decoration: const InputDecoration(labelText: 'Reset token', helperText: 'Usually filled from the email link')),
        const SizedBox(height: 14),
        TextField(controller: _password, obscureText: _hide, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'New password', suffixIcon: IconButton(onPressed: () => setState(() => _hide = !_hide), icon: Icon(_hide ? Icons.visibility_off : Icons.visibility)))),
        const SizedBox(height: 8),
        Text('8+ characters: uppercase ${RegExp(r'[A-Z]').hasMatch(_password.text) ? '✓' : '○'}  lowercase ${RegExp(r'[a-z]').hasMatch(_password.text) ? '✓' : '○'}  number ${RegExp(r'[0-9]').hasMatch(_password.text) ? '✓' : '○'}  special ${RegExp(r'[^A-Za-z0-9]').hasMatch(_password.text) ? '✓' : '○'}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 14),
        TextField(controller: _confirm, obscureText: _hideConfirm, decoration: InputDecoration(labelText: 'Confirm new password', suffixIcon: IconButton(onPressed: () => setState(() => _hideConfirm = !_hideConfirm), icon: Icon(_hideConfirm ? Icons.visibility_off : Icons.visibility)))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: const TextStyle(color: statusBad))),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Update password')),
      ]),
    ))),
  );
}
