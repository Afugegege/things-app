import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

class AuthService {
  static final _supabase = Supabase.instance.client;

  // Current User
  static User? get currentUser => _supabase.auth.currentUser;

  // Stream of auth changes
  static Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sign Up with Email
  static Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Sign In with Email
  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign In with Google
  static Future<void> signInWithGoogle() async {
    // Web-based OAuth (Easy/Standard - no mobile config needed)
    await _supabase.auth.signInWithOAuth(OAuthProvider.google);
  }

  // Sign Out
  static Future<void> signOut() async {
    await _supabase.auth.signOut();
    await gsi.GoogleSignIn().signOut();
  }
}
