import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthError {
  invalidCredentials,
  emailNotVerified,
  accountInactive,
  userNotFound,
  networkError,
  emailAlreadyInUse,
  weakPassword,
  unknownError,
}

class AuthResult {
  final bool success;
  final AuthError? error;
  final String? message;
  final User? user;

  AuthResult.success({this.user, this.message}) : success = true, error = null;

  AuthResult.failure(this.error, {this.message, this.user}) : success = false;
}

class User {
  final String id;
  final String email;
  final String name;
  final String role; // admin, rhu_staff, hospital_staff, encoder, bhw, bsi, pending
  final String? rhuId;
  final String? facilityId;
  final String? barangayId;
  final List<String>? barangayCoverage; // backward compatibility
  final List<String>? team;
  final bool isActive;
  final bool emailVerified;
  final bool requiresPasswordSetup;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.rhuId,
    this.facilityId,
    this.barangayId,
    this.barangayCoverage,
    this.team,
    required this.isActive,
    this.emailVerified = false,
    this.requiresPasswordSetup = false,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    final role = (map['role'] as String?) ?? 'rhu_staff';
    return User(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      role: role,
      rhuId: map['rhu_id'] as String?,
      facilityId: map['facility_id'] as String?,
      barangayId: map['barangay_id'] as String?,
      barangayCoverage: map['covered_barangay'] != null
          ? List<String>.from(map['covered_barangay'] as List)
          : null,
      team: map['team'] != null ? List<String>.from(map['team'] as List) : null,
      isActive: map['active'] as bool? ?? true,
      emailVerified: map['email_verified'] as bool? ?? false,
      requiresPasswordSetup: map['password_setup_required'] as bool? ?? false,
    );
  }

  /// Check if user can access a specific barangay based on role and assignments
  bool canAccessBarangay(String barangayId) {
    if (role == 'admin') return true;
    if (role == 'rhu_staff') return true; // RHU staff can see their entire RHU
    if (this.barangayId == barangayId) return true;
    if (barangayCoverage?.contains(barangayId) ?? false) return true;
    return false;
  }

  /// Check if user can access a specific RHU
  bool canAccessRHU(String rhuId) {
    if (role == 'admin') return true;
    if (this.rhuId == rhuId) return true;
    return false;
  }

  /// Check if user can access a specific facility
  bool canAccessFacility(String facilityId) {
    if (role == 'admin') return true;
    if (this.facilityId == facilityId) return true;
    return false;
  }
}

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPasswordRecovery = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPasswordRecovery => _isPasswordRecovery;

  AuthService() {
    _initializeAuth();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
        notifyListeners();
      }
      final session = data.session;
      if (session == null) {
        _currentUser = null;
        _isPasswordRecovery = false;
        notifyListeners();
      } else if (_currentUser == null || _currentUser!.id != session.user.id) {
        _loadUserProfile(session.user.id);
      }
    });
  }

  Future<void> _initializeAuth() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        await _loadUserProfile(session.user.id);
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      _errorMessage = 'Failed to initialize authentication';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      final user = User.fromMap(response);

      // An invited user must be allowed into the limited password setup screen
      // before an administrator activates their account.
      if (!user.isActive && !user.requiresPasswordSetup) {
        await signOut();
        _errorMessage = 'Your account has been deactivated. Please contact your administrator.';
        notifyListeners();
        return;
      }

      // Check email verification status
      final authUser = _supabase.auth.currentUser;
      if (authUser != null && authUser.emailConfirmedAt == null) {
        await signOut();
        _errorMessage = 'Please verify your email address before logging in.';
        notifyListeners();
        return;
      }

      _currentUser = user;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      _errorMessage = 'Failed to load user profile';
      await signOut();
    }
  }

  Future<AuthResult> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        // Check email verification
        if (response.user!.emailConfirmedAt == null) {
          await signOut();
          return AuthResult.failure(
            AuthError.emailNotVerified,
            message: 'Please verify your email address. Check your inbox for the verification link.',
          );
        }

        // Load user profile to check account status
        await _loadUserProfile(response.user!.id);

        if (_currentUser != null) {
          return AuthResult.success(user: _currentUser);
        } else {
          return AuthResult.failure(
            AuthError.userNotFound,
            message:
                'User profile not found. Please contact your administrator.',
          );
        }
      }

      return AuthResult.failure(
        AuthError.invalidCredentials,
        message: 'Invalid email or password',
      );
    } on AuthException catch (e) {
      debugPrint('Auth exception: ${e.message}');

      if (e.message.contains('Invalid login credentials')) {
        return AuthResult.failure(
          AuthError.invalidCredentials,
          message: 'Invalid email or password',
        );
      } else if (e.message.contains('Email not confirmed')) {
        return AuthResult.failure(
          AuthError.emailNotVerified,
          message: 'Please verify your email address before logging in.',
        );
      } else {
        return AuthResult.failure(
          AuthError.unknownError,
          message: 'Authentication failed',
        );
      }
    } catch (e) {
      debugPrint('Sign in error: $e');
      return AuthResult.failure(
        AuthError.networkError,
        message: 'Network error. Please check your connection and try again.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthResult> resendVerificationEmail() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return AuthResult.failure(
          AuthError.userNotFound,
          message: 'No user is currently logged in',
        );
      }

      await _supabase.auth.resend(type: OtpType.signup, email: user.email);

      return AuthResult.success(
        message:
            'Verification email sent successfully. Please check your inbox.',
      );
    } catch (e) {
      debugPrint('Resend verification error: $e');
      return AuthResult.failure(
        AuthError.unknownError,
        message: 'Failed to resend verification email',
      );
    }
  }

  Future<AuthResult> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'salcedo-dengue-watch://auth-callback/',
      );

      return AuthResult.success(
        message: 'Password reset email sent. Please check your inbox.',
      );
    } catch (e) {
      debugPrint('Reset password error: $e');
      return AuthResult.failure(
        AuthError.unknownError,
        message: 'Failed to send password reset email. Please check your email address.',
      );
    }
  }

  Future<AuthResult> updatePassword(
    String newPassword, {
    bool completeSetup = true,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      if (completeSetup) await _supabase.rpc('complete_user_setup');

      _isPasswordRecovery = false;
      final authUser = _supabase.auth.currentUser;
      final profile = _currentUser;
      if (authUser != null && profile != null && !profile.isActive) {
        await signOut();
        return AuthResult.success(
          message: 'Password saved. Your account is waiting for administrator approval.',
        );
      }
      if (authUser != null) await _loadUserProfile(authUser.id);

      return AuthResult.success(message: 'Password updated successfully');
    } catch (e) {
      debugPrint('Update password error: $e');
      return AuthResult.failure(
        AuthError.unknownError,
        message: 'Failed to update password',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthResult> signOut() async {
    try {
      await _supabase.auth.signOut();
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
      return AuthResult.success(message: 'Logged out successfully');
    } catch (e) {
      debugPrint('Sign out error: $e');
      return AuthResult.failure(
        AuthError.unknownError,
        message: 'Failed to log out',
      );
    }
  }

  bool hasAccessToBarangay(String barangay) {
    if (_currentUser?.role == 'admin') return true;
    return _currentUser?.barangayCoverage?.contains(barangay) ?? false;
  }

  String getErrorMessageForError(AuthError error) {
    switch (error) {
      case AuthError.invalidCredentials:
        return 'Invalid email or password';
      case AuthError.emailNotVerified:
        return 'Please verify your email address before logging in';
      case AuthError.accountInactive:
        return 'Your account has been deactivated. Please contact your administrator';
      case AuthError.userNotFound:
        return 'User profile not found. Please contact your administrator';
      case AuthError.networkError:
        return 'Network error. Please check your connection and try again';
      case AuthError.emailAlreadyInUse:
        return 'This email is already registered';
      case AuthError.weakPassword:
        return 'Password is too weak. Please use a stronger password';
      case AuthError.unknownError:
        return 'An unexpected error occurred';
    }
  }
}
