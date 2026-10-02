import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web : Google requires its own button, the sign-in arrives in GoogleSignInService.webIdTokens.
Widget googleWebButton() => web.renderButton(
      configuration: web.GSIButtonConfiguration(
        text: web.GSIButtonText.continueWith,
        shape: web.GSIButtonShape.pill,
        size: web.GSIButtonSize.large,
      ),
    );
