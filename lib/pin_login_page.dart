// lib/pin_login_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'auth_service.dart';

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  String _pin = '';
  bool _isLoading = false;

  void _onNumberPressed(String value) {
    if (_pin.length < 4) {
      setState(() {
        _pin += value;
      });
    }
  }

  void _onBackspacePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _submitPin() async {
    if (_pin.length != 4) return;

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.loginWithPin(_pin);

    if (success) {
      if (mounted) context.go('/order-type-selection');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // <-- FIXED: showSnackBar
          const SnackBar(
            // <-- FIXED: SnackBar
            content: Text('Invalid PIN. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _pin = '';
        _isLoading = false;
      });
    }
  } // <-- FIXED: Added missing '}' here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Please Enter Your 4-Digit PIN',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: index < _pin.length
                        ? Colors.indigo
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 300,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  if (index == 9) return const SizedBox.shrink();
                  if (index == 10) {
                    return _buildKeypadButton('0', _onNumberPressed);
                  }
                  if (index == 11) {
                    return _buildKeypadButton(
                      '⌫',
                      (_) => _onBackspacePressed(),
                      isIcon: true,
                    );
                  }
                  final number = (index + 1).toString();
                  return _buildKeypadButton(number, _onNumberPressed);
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 300,
              height: 50,
              child: ElevatedButton(
                onPressed: (_pin.length == 4 && !_isLoading)
                    ? _submitPin
                    : null,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(
    String value,
    Function(String) onPressed, {
    bool isIcon = false,
  }) {
    return InkWell(
      onTap: () => onPressed(value),
      borderRadius: BorderRadius.circular(40),
      child: Center(
        child: isIcon
            ? const Icon(Icons.backspace_outlined, size: 28)
            : Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
