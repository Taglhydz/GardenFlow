class AppConstants {
  // API Configuration
  static const String baseUrl = 'http://localhost:3000/api';
  
  // API Endpoints
  static const String authEndpoint = '/auth';
  static const String usersEndpoint = '/users';
  static const String gardensEndpoint = '/gardens';
  static const String parcelsEndpoint = '/parcels';
  static const String plantsEndpoint = '/plants';
  static const String cropsEndpoint = '/crops';
  static const String plantAssociationsEndpoint = '/plant-associations';
  static const String suggestionsEndpoint = '/suggestions';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  
  // App Info
  static const String appName = 'GardenFlow';
  static const String appVersion = '1.0.0';
}
