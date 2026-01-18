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
  static Future<AuthResponse> signInWithGoogle() async {
    // 1. Web-based OAuth (Easy/Standard)
    // return await _supabase.auth.signInWithOAuth(Provider.google);

    // 2. Native Google Sign In (Better UX for Mobile)
    const webClientId = 'YOUR_WEB_CLIENT_ID_FROM_GCP'; // TODO: User needs to insert this eventually, or we use environmental variables.
    
    final gsi.GoogleSignIn googleSignIn = gsi.GoogleSignIn(
      // serverClientId: webClientId,
    );
    final gsi.GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    
    if (googleUser == null) {
      throw 'Google Sign In aborted';
    }

    final gsi.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) {
      throw 'No Access Token found.';
    }
    if (idToken == null) {
      throw 'No ID Token found.';
    }

    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // Sign Out
  static Future<void> signOut() async {
    await _supabase.auth.signOut();
    await gsi.GoogleSignIn().signOut();
  }
}
