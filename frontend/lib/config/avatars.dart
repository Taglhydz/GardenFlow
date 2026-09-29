/// Plant avatars a user can choose instead of a photo (`assets/avatars/CODE.svg`).
/// The codes must stay in sync with AVATARS in the backend (validators/common.js).
class Avatars {
  Avatars._();

  static const List<String> codes = [
    'tomato', 'carrot', 'sunflower', 'basil', 'strawberry', 'pumpkin',
    'eggplant', 'radish', 'lettuce', 'pepper', 'corn', 'pea',
  ];

  static String asset(String code) => 'assets/avatars/$code.svg';
}
