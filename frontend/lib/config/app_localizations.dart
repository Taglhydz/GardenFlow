import 'package:easy_localization/easy_localization.dart';
import '../models/plant.dart';
import '../models/plant_association.dart';
import '../models/suggestion.dart';
import '../services/api_service.dart';

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
///
/// 5. Plantes : la base de données stocke les textes en français,
///    les autres langues sont dans les fichiers JSON (plants.<code>.name).
///    Text(AppLocalizations.plantName(plant))
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

  /// Obtient le label traduit pour le type de plante
  static String getPlantTypeLabel(String plantType) {
    return 'plant_type_$plantType'.tr();
  }

  /// Obtient le label traduit pour une famille botanique (le code brut si elle n'est pas traduite)
  static String getPlantFamilyLabel(String family) {
    return _translatedOr('plant_family_$family', family);
  }

  /// Obtient le label traduit pour un type de période du calendrier (semis, plantation, récolte)
  static String getPeriodLabel(String periodType) {
    return 'period_$periodType'.tr();
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

  /// Nom de la plante dans la langue de l'app, sinon le nom français de la base.
  static String plantName(Plant plant) {
    return _translatedOr('plants.${plant.code}.name', plant.name);
  }

  /// Description de la plante dans la langue de l'app, sinon la description française de la base.
  static String? plantDescription(Plant plant) {
    if (plant.description == null) return null;
    return _translatedOr('plants.${plant.code}.description', plant.description!);
  }

  /// Commentaire d'une association dans la langue de l'app, sinon le commentaire français de la base.
  static String? associationComment(PlantAssociation association) {
    if (association.comment == null) return null;
    return _translatedOr(association.translationKey, association.comment!);
  }

  /// Raison d'une suggestion, traduite avec ses paramètres (suggestion_reasons.<code>).
  /// [plantsByCode] sert à afficher le nom traduit des plantes citées.
  static String suggestionReason(SuggestionReason reason, Map<String, Plant> plantsByCode) {
    final params = reason.params;
    final plantCode = params['plant_code'] as String?;
    final plant = plantCode != null ? plantsByCode[plantCode] : null;

    final args = <String, String>{
      if (plantCode != null) 'plant': plant != null ? plantName(plant) : plantCode,
      if (params['preferred_soil'] != null) 'soil': getSoilTypeLabel(params['preferred_soil'] as String).toLowerCase(),
      // 'need' is a sunlight level for sun_too_low, a water need for too_dry / too_wet
      if (params['need'] != null)
        'need': (reason.code.startsWith('sun')
                ? getSunlightLabel(params['need'] as String)
                : getWaterNeedLabel(params['need'] as String))
            .toLowerCase(),
      if (params['family'] != null) 'family': getPlantFamilyLabel(params['family'] as String),
      if (params['months_ago'] != null) 'months': '${params['months_ago']}',
    };

    final key = 'suggestion_reasons.${reason.code}';
    return trExists(key) ? key.tr(namedArgs: args) : reason.code;
  }

  /// Mesure en mètres dans le format de la langue : 2,5 m / 2.5 m
  static String meters(double value) {
    return '${NumberFormat('0.##').format(value)} m';
  }

  /// Dimensions d'une parcelle : 2 × 1,5 m
  static String dimensions(double width, double length) {
    final format = NumberFormat('0.##');
    return '${format.format(width)} × ${format.format(length)} m';
  }

  /// Message d'erreur traduit à afficher à l'utilisateur (errors.<code> des fichiers JSON).
  static String errorMessage(Object error) {
    if (error is ApiException && trExists('errors.${error.code}')) {
      return 'errors.${error.code}'.tr();
    }
    return 'errors.UNKNOWN'.tr();
  }

  static String _translatedOr(String key, String fallback) {
    return trExists(key) ? key.tr() : fallback;
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
