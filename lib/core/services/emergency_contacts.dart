// Emergency and crisis numbers (Doc 16 Q-HELPLINE safe default: 108 / 112
// emergency, Tele-MANAS 14416; region configuration pending OQ-REQ-16).
import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

class EmergencyContact {
  const EmergencyContact(this.label, this.number, this.sub);
  final String label;
  final String number;
  final String sub;
}

class EmergencyContacts {
  EmergencyContacts._();

  static const List<EmergencyContact> emergency = [
    EmergencyContact('Ambulance 108', '108', 'Emergency medical services'),
    EmergencyContact('Emergency 112', '112', 'National emergency number'),
  ];

  static const List<EmergencyContact> crisis = [
    EmergencyContact(
      'Tele-MANAS 14416',
      '14416',
      '24 × 7 mental-health helpline, free, all languages',
    ),
    EmergencyContact(
      'Tele-MANAS 1-800-891-4416',
      '18008914416',
      'Toll-free alternative number',
    ),
    EmergencyContact(
      'Emergency 112',
      '112',
      'If someone is in immediate danger',
    ),
  ];

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Opens the dialler with [number]; returns false when no dialler exists.
  static Future<bool> dial(String number) async {
    if (isFlutterTest) return true;
    final uri = Uri(scheme: 'tel', path: number);
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
