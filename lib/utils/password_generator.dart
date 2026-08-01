import 'dart:math';

String generatePassword({
  required bool upperCase,
  required bool lowerCase,
  required bool numeric,
  required bool special,
  required int length,
}) {
  const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const lower = 'abcdefghijklmnopqrstuvwxyz';
  const numbers = '0123456789';
  const specials = '!@#\$%^&*()-_=+[]{}|;:,.<>?';
  String chars = '';
  if (upperCase) chars += upper;
  if (lowerCase) chars += lower;
  if (numeric) chars += numbers;
  if (special) chars += specials;
  if (chars.isEmpty) return '';
  final rand = Random.secure();
  List<String> password = [];
  if (upperCase) password.add(upper[rand.nextInt(upper.length)]);
  if (lowerCase) password.add(lower[rand.nextInt(lower.length)]);
  if (numeric) password.add(numbers[rand.nextInt(numbers.length)]);
  if (special) password.add(specials[rand.nextInt(specials.length)]);
  while (password.length < length) {
    password.add(chars[rand.nextInt(chars.length)]);
  }
  password.shuffle(rand);
  return password.join();
}
