import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // API Configuration - Chargée depuis .env
  static String get baseUrl   => dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/api';
  static bool   get debugMode => dotenv.env['DEBUG_MODE'  ] == 'true';

  // Google sign-in : OAuth client id of type "Web" (same as GOOGLE_CLIENT_ID of the backend), empty = no Google button
  static String get googleClientId => dotenv.env['GOOGLE_CLIENT_ID'] ?? '';

  // API Endpoints
  static const String authEndpoint              = '/auth'              ;
  static const String usersEndpoint             = '/users'             ;
  static const String gardensEndpoint           = '/gardens'           ;
  static const String parcelsEndpoint           = '/parcels'           ;
  static const String plantsEndpoint            = '/plants'            ;
  static const String cropsEndpoint             = '/crops'             ;
  static const String zonesEndpoint             = '/zones'             ;
  static const String plantAssociationsEndpoint = '/plant-associations';
  static const String plantColorsEndpoint       = '/users/me/plant-colors';

  // Storage Keys
  static const String tokenKey        = 'auth_token'    ; // secure storage
  static const String lastGardenIdKey = 'last_garden_id'; // shared preferences
  static const String snapKey         = 'snap_cm'       ; // shared preferences (0 = magnet off)
  static const String hiddenHelpKey   = 'hidden_help'   ; // shared preferences (help banners closed)
  static const String welcomeEmailKey = 'welcome_email' ; // shared preferences (account created, welcome shown at its first login)

  // Validation rules (must match the backend validators)
  static const int passwordMinLength = 10;
  static const int usernameMinLength = 3;

  // App Info
  static const String appName    = 'GardenFlow';
  static const String appVersion = '1.0.0';
}

class AppColors {
  // Couleurs principales
  static const Color primary      = Color(0xFF4CAF50); // green principal
  static const Color primaryLight = Color(0xFFC8E6C9); // light green
  static const Color primaryDark  = Color(0xFF388E3C); // dark green

  // Couleurs fonctionnelles
  static const Color success = Color(0xFF4CAF50); // green
  static const Color error   = Color(0xFFF44336); // red
  static const Color warning = Color(0xFFFF9800); // orange
  static const Color info    = Color(0xFF2196F3); // blue

  // Couleurs pour les modules
  static const Color gardens = Color(0xFF4CAF50); // green
  static const Color parcels = Color(0xFF795548); // brown
  static const Color plants  = Color(0xFFE91E63); // pink
  static const Color crops   = Color(0xFFFF9800); // orange

  // Couleurs neutres
  static const Color white     = Color(0xFFFFFFFF);
  static const Color black     = Color(0xFF000000);
  static const Color grey      = Color(0xFF9E9E9E);
  static const Color greyLight = Color(0xFFE0E0E0);
  static const Color greyDark  = Color(0xFF616161);

  // Couleurs de fond
  static const Color background     = Color(0xFFFAFAFA); // light grey
  static const Color surface        = Color(0xFFFFFFFF); // white
  static const Color cardBackground = Color(0xFFFFFFFF); // white
}
