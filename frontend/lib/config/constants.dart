import 'package:flutter/material.dart';

class AppConstants {
  // API Configuration
  static const String baseUrl = 'http://localhost:3000/api';
  
  // API Endpoints
  static const String authEndpoint              = '/auth'              ;
  static const String usersEndpoint             = '/users'             ;
  static const String gardensEndpoint           = '/gardens'           ;
  static const String parcelsEndpoint           = '/parcels'           ;
  static const String plantsEndpoint            = '/plants'            ;
  static const String cropsEndpoint             = '/crops'             ;
  static const String plantAssociationsEndpoint = '/plant-associations';
  static const String suggestionsEndpoint       = '/suggestions'       ;
  
  // Storage Keys
  static const String tokenKey  = 'auth_token';
  static const String userIdKey = 'user_id';
  
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
