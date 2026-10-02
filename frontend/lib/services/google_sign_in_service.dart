import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In : gives the ID token that the backend checks (POST /auth/google).
/// [clientId] : OAuth client id of type "Web" of the Google Cloud project (GOOGLE_CLIENT_ID in .env).
class GoogleSignInService {
  GoogleSignInService({required this.clientId});

  final String clientId;
  Future<void>? _initialization;

  /// Android and web. Not Windows / Linux (not supported by Google), nor iOS / macOS (they need their own client id).
  bool get isAvailable =>
      clientId.isNotEmpty && (kIsWeb || defaultTargetPlatform == TargetPlatform.android);

  /// On the web, Google draws its own button (widgets/google_sign_in_button.dart) and the sign-in arrives in [webIdTokens].
  bool get usesGoogleButton => kIsWeb;

  // Android : the token must be issued for the "Web" client (serverClientId), the one the backend checks.
  // Web : that same client identifies the site (clientId).
  Future<void> _initialize() => _initialization ??= GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? clientId : null,
        serverClientId: kIsWeb ? null : clientId,
      );

  /// Opens the Google account chooser (Android). null if the user closes it.
  /// Throws a [GoogleSignInException] when Google refuses (bad configuration in the Google Cloud console...).
  Future<String?> signIn() async {
    await _initialize();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Web : ID token of each sign-in made with the Google button.
  Stream<String> webIdTokens() async* {
    await _initialize();
    yield* GoogleSignIn.instance.authenticationEvents
        .where((event) => event is GoogleSignInAuthenticationEventSignIn)
        .map((event) => (event as GoogleSignInAuthenticationEventSignIn).user.authentication.idToken)
        .where((idToken) => idToken != null)
        .cast<String>();
  }

  /// At logout : the next Google sign-in asks for the account again instead of reusing the last one.
  Future<void> signOut() async {
    if (_initialization == null) return;
    await _initialization;
    await GoogleSignIn.instance.signOut();
  }
}
