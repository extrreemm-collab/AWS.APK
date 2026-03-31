import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/google_auth.dart';
import '../services/session_store.dart';

enum SessionStatus { loading, signedOut, authenticated, unsupportedRole }

class SessionController extends ChangeNotifier {
  SessionController({
    required this.api,
    required this.store,
    required this.googleAuth,
  });

  final AmsApi api;
  final SessionStore store;
  final GoogleAuthClient googleAuth;

  SessionStatus status = SessionStatus.loading;
  SessionUser? user;
  String? token;
  String? errorMessage;
  LoginRole? selectedRole;
  bool isBusy = false;

  String get apiBaseUrl => api.baseUrl;

  String get requireToken {
    final currentToken = token;
    if (currentToken == null) {
      throw StateError('No active AMS session is available.');
    }
    return currentToken;
  }

  Future<void> initialize() async {
    status = SessionStatus.loading;
    notifyListeners();

    final storedSession = await store.read();
    if (storedSession == null) {
      status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }

    try {
      final refreshedUser = await api.fetchCurrentUser(storedSession.token);
      await store.save(token: storedSession.token, user: refreshedUser);
      _applyAuthenticatedState(refreshedUser, storedSession.token);
    } on ApiException catch (error) {
      await _resetSession(
        error.isUnauthorized
            ? 'Your session expired. Please sign in again.'
            : error.message,
      );
    } catch (_) {
      await _resetSession('Could not restore your session.');
    }
  }

  Future<bool> signInWithGoogle() async {
    final role = _requireSelectedRole();
    if (role == null) {
      return false;
    }

    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      final googleIdentity = await googleAuth.signIn();
      if (googleIdentity == null) {
        isBusy = false;
        notifyListeners();
        return false;
      }

      return await _completeGoogleSignIn(googleIdentity, role);
    } on GoogleAuthException catch (error) {
      isBusy = false;
      errorMessage = error.message;
      notifyListeners();
      return false;
    } on ApiException catch (error) {
      await googleAuth.signOut();
      isBusy = false;
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      isBusy = false;
      errorMessage = 'Something went wrong while signing in.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogleIdentity(GoogleIdentity googleIdentity) async {
    final role = _requireSelectedRole();
    if (role == null) {
      return false;
    }

    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await _completeGoogleSignIn(googleIdentity, role);
    } on ApiException catch (error) {
      await googleAuth.signOut();
      isBusy = false;
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      isBusy = false;
      errorMessage = 'Something went wrong while signing in.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await googleAuth.signOut();
    await _resetSession();
  }

  Future<void> handleUnauthorized([
    String message = 'Your session expired. Please sign in again.',
  ]) async {
    await _resetSession(message);
  }

  void setSignInError(String message) {
    isBusy = false;
    errorMessage = message;
    notifyListeners();
  }

  void selectRole(LoginRole role) {
    if (selectedRole == role && errorMessage == null) {
      return;
    }

    selectedRole = role;
    errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }
    errorMessage = null;
    notifyListeners();
  }

  void _applyAuthenticatedState(SessionUser nextUser, String nextToken) {
    user = nextUser;
    token = nextToken;
    selectedRole = LoginRoleX.fromApi(nextUser.role);
    status = nextUser.isSupportedRole
        ? SessionStatus.authenticated
        : SessionStatus.unsupportedRole;
    errorMessage = nextUser.isSupportedRole
        ? null
        : 'This account is authenticated, but AMS does not recognize the assigned role.';
    notifyListeners();
  }

  Future<void> _resetSession([String? message]) async {
    await store.clear();
    user = null;
    token = null;
    selectedRole = null;
    isBusy = false;
    status = SessionStatus.signedOut;
    errorMessage = message;
    notifyListeners();
  }

  LoginRole? _requireSelectedRole() {
    final role = selectedRole;
    if (role != null) {
      return role;
    }

    errorMessage = 'Select your role before continuing with Google.';
    notifyListeners();
    return null;
  }

  Future<bool> _completeGoogleSignIn(
    GoogleIdentity googleIdentity,
    LoginRole role,
  ) async {
    final response = await api.authenticateWithGoogle(
      idToken: googleIdentity.idToken,
      role: role.apiValue,
    );
    await store.save(token: response.accessToken, user: response.user);
    isBusy = false;
    _applyAuthenticatedState(response.user, response.accessToken);
    return true;
  }
}
