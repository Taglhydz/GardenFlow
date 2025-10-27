import 'package:easy_localization/easy_localization.dart';

/// Classe utilitaire pour faciliter l'accès aux traductions
/// 
/// Exemple d'utilisation dans vos widgets :
/// 
/// 1. Import simple :
///    Text('welcome'.tr())
/// 
/// 2. Avec contexte :
///    Text(context.tr('welcome'))
/// 
/// 3. Pour les énumérations du schéma SQL :
///    String soilTypeLabel = AppLocalizations.getSoilTypeLabel('clay');
///    // Retourne "Argileux" en français ou "Clay" en anglais
/// 
/// 4. Changer de langue :
///    await context.setLocale(Locale('en'));
class AppLocalizations {
  
  /// Obtient le label traduit pour un type de sol
  static String getSoilTypeLabel(String soilType) {
    return 'soil_type_$soilType'.tr();
  }

  /// Obtient le label traduit pour l'ensoleillement
  static String getSunlightLabel(String sunlight) {
    return 'sunlight_$sunlight'.tr();
  }

  /// Obtient le label traduit pour l'humidité
  static String getMoistureLabel(String moisture) {
    return 'moisture_$moisture'.tr();
  }

  /// Obtient le label traduit pour le besoin en eau
  static String getWaterNeedLabel(String waterNeed) {
    return 'water_need_$waterNeed'.tr();
  }

  /// Obtient le label traduit pour le rôle utilisateur
  static String getRoleLabel(String role) {
    return 'role_$role'.tr();
  }

  /// Obtient le nom du mois traduit
  static String getMonthName(int month) {
    return 'month_$month'.tr();
  }

  /// Obtient le label traduit pour le type de relation (association)
  static String getRelationTypeLabel(String relationType) {
    return relationType.tr();
  }

  /// Liste de tous les types de sol avec leurs labels
  static List<Map<String, String>> get soilTypes => [
    {'value': 'standard', 'label': getSoilTypeLabel('standard')},
    {'value': 'clay', 'label': getSoilTypeLabel('clay')},
    {'value': 'sandy', 'label': getSoilTypeLabel('sandy')},
    {'value': 'loamy', 'label': getSoilTypeLabel('loamy')},
    {'value': 'humus', 'label': getSoilTypeLabel('humus')},
    {'value': 'chalky', 'label': getSoilTypeLabel('chalky')},
  ];

  /// Liste de tous les niveaux d'ensoleillement avec leurs labels
  static List<Map<String, String>> get sunlightLevels => [
    {'value': 'low', 'label': getSunlightLabel('low')},
    {'value': 'medium', 'label': getSunlightLabel('medium')},
    {'value': 'high', 'label': getSunlightLabel('high')},
  ];

  /// Liste de tous les niveaux d'humidité avec leurs labels
  static List<Map<String, String>> get moistureLevels => [
    {'value': 'low', 'label': getMoistureLabel('low')},
    {'value': 'medium', 'label': getMoistureLabel('medium')},
    {'value': 'high', 'label': getMoistureLabel('high')},
  ];

  /// Liste de tous les besoins en eau avec leurs labels
  static List<Map<String, String>> get waterNeeds => [
    {'value': 'low', 'label': getWaterNeedLabel('low')},
    {'value': 'medium', 'label': getWaterNeedLabel('medium')},
    {'value': 'high', 'label': getWaterNeedLabel('high')},
  ];

  /// Liste de tous les mois avec leurs labels
  static List<Map<String, dynamic>> get months => List.generate(
    12,
    (index) => {
      'value': index + 1,
      'label': getMonthName(index + 1),
    },
  );
}
