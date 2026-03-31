import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/google_auth.dart';
import '../services/google_auth_web_button.dart';
import '../state/session_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _submit() async {
    await widget.sessionController.signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = widget.sessionController.errorMessage;
    final googleAuth = widget.sessionController.googleAuth;
    final selectedRole = widget.sessionController.selectedRole;
    final showWebButton = kIsWeb && googleAuth is GoogleSignInAuthClient;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF0B3B53), Color(0xFFF3EDE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -40,
              child: _GlowCircle(
                size: 220,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              top: 120,
              right: -36,
              child: _GlowCircle(
                size: 150,
                color: const Color(0xFFFFEDD5).withValues(alpha: 0.35),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _AppLogo(),
                            const SizedBox(height: 18),
                            Text(
                              'Attendance Master Scholar',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sign in using your college email account.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: const Color(0xFF475569)),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sign in with your college Google account to access attendance services.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Select your role',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: LoginRole.values
                                  .map(
                                    (role) => SizedBox(
                                      width: 190,
                                      child: _RoleCard(
                                        role: role,
                                        isSelected: selectedRole == role,
                                        onTap: widget.sessionController.isBusy
                                            ? null
                                            : () => widget.sessionController
                                                  .selectRole(role),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: errorMessage == null
                                  ? const SizedBox.shrink()
                                  : Container(
                                      key: ValueKey(errorMessage),
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 18),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFFCA5A5),
                                        ),
                                      ),
                                      child: Text(
                                        errorMessage,
                                        style: const TextStyle(
                                          color: Color(0xFF991B1B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: selectedRole == null
                                  ? Container(
                                      key: const ValueKey('role-helper'),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFA7F3D0),
                                        ),
                                      ),
                                      child: const Text(
                                        'Choose your role to continue with Google sign-in.',
                                        style: TextStyle(
                                          color: Color(0xFF065F46),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      key: ValueKey(selectedRole.apiValue),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFD7DFE8),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Continue as ${selectedRole.label}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            selectedRole.helperText,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: const Color(
                                                    0xFF64748B,
                                                  ),
                                                ),
                                          ),
                                          const SizedBox(height: 16),
                                          if (showWebButton)
                                            IgnorePointer(
                                              ignoring: widget
                                                  .sessionController
                                                  .isBusy,
                                              child: GoogleWebSignInButton(
                                                client: googleAuth,
                                                onIdentity: (identity) => widget
                                                    .sessionController
                                                    .signInWithGoogleIdentity(
                                                      identity,
                                                    ),
                                                onError: widget
                                                    .sessionController
                                                    .setSignInError,
                                              ),
                                            )
                                          else
                                            FilledButton.icon(
                                              onPressed:
                                                  widget
                                                      .sessionController
                                                      .isBusy
                                                  ? null
                                                  : _submit,
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor: const Color(
                                                  0xFF0F172A,
                                                ),
                                                side: const BorderSide(
                                                  color: Color(0xFFD7DFE8),
                                                ),
                                              ),
                                              icon:
                                                  widget
                                                      .sessionController
                                                      .isBusy
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const _GoogleBadge(),
                                              label: Text(
                                                widget.sessionController.isBusy
                                                    ? 'Connecting to Google...'
                                                    : 'Continue with Google',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Text(
                                'Only registered college accounts can access AMS. If your account has not been added yet, contact your administrator.',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330F766E),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.fact_check_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final LoginRole role;
  final bool isSelected;
  final VoidCallback? onTap;

  IconData get _icon => switch (role) {
    LoginRole.principal => Icons.workspace_premium_rounded,
    LoginRole.hod => Icons.account_balance_rounded,
    LoginRole.lecturer => Icons.co_present_rounded,
    LoginRole.student => Icons.school_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F766E)
                : const Color(0xFFD7DFE8),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x1F0F766E),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: const Color(0xFF0F766E), size: 28),
            const SizedBox(height: 14),
            Text(
              role.label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              role.helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
