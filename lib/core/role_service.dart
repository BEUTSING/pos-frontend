import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

// ═══════════════════════════════════════════════════════════════
// ROLE SERVICE — Gestion centralisée des rôles utilisateur
//
// Rôles Symfony (hiérarchie) :
//   ROLE_ADMIN   → tout
//   ROLE_MANAGER → tout sauf créer restaurant
//   ROLE_TELLER  → commandes + ventes
//   ROLE_WAITER  → commandes + voir produits/catégories
// ═══════════════════════════════════════════════════════════════
class RoleService {
  static final RoleService _instance = RoleService._internal();
  factory RoleService() => _instance;
  RoleService._internal();

  // Rôle en cache mémoire pour éviter trop d'accès SharedPrefs
  String _cachedRole = '';

  // ── Sauvegarder le rôle après login ─────────────────────────
  Future<void> saveRole(String role) async {
    _cachedRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserRole, role);
  }

  // ── Sauvegarder le nom après login ───────────────────────────
  Future<void> saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserName, name);
  }

  // ── Lire le rôle stocké ──────────────────────────────────────
  Future<String> getRole() async {
    if (_cachedRole.isNotEmpty) return _cachedRole;
    final prefs = await SharedPreferences.getInstance();
    _cachedRole = prefs.getString(kUserRole) ?? '';
    return _cachedRole;
  }

  // ── Vider le cache (au logout) ───────────────────────────────
  void clearCache() => _cachedRole = '';

  // ════════════════════════════════════════════════════════════
  // VÉRIFICATIONS DE RÔLE
  // ════════════════════════════════════════════════════════════

  Future<bool> isAdmin() async {
    final r = await getRole();
    return r == 'ROLE_ADMIN';
  }

  // Manager ET Admin
  Future<bool> isManagerOrAbove() async {
    final r = await getRole();
    return r == 'ROLE_ADMIN' || r == 'ROLE_MANAGER';
  }

  // Teller, Manager ET Admin
  Future<bool> isTellerOrAbove() async {
    final r = await getRole();
    return r == 'ROLE_ADMIN' ||
        r == 'ROLE_MANAGER' ||
        r == 'ROLE_TELLER';
  }

  // Tous les rôles connectés
  Future<bool> isWaiterOrAbove() async {
    final r = await getRole();
    return r == 'ROLE_ADMIN' ||
        r == 'ROLE_MANAGER' ||
        r == 'ROLE_TELLER' ||
        r == 'ROLE_WAITER';
  }

  // ── Décodeur JWT (payload base64) ─────────────────────────────
  // Extrait les champs "roles" et "name"/"username" du token Symfony
  static Map<String, dynamic> decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};

      // Padding base64
      String payload = parts[1];
      final mod = payload.length % 4;
      if (mod != 0) payload += '=' * (4 - mod);

      // Décoder base64url → bytes → string UTF-8
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final bytes = _base64Decode(normalized);
      final jsonStr = String.fromCharCodes(bytes);

      // Parser le JSON manuellement (sans dart:convert pour rester simple)
      return _parseSimpleJson(jsonStr);
    } catch (e) {
      return {};
    }
  }

  // Décodage base64 manuel
  static List<int> _base64Decode(String s) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final bytes = <int>[];
    var buffer = 0;
    var bitsLeft = 0;
    for (final c in s.runes) {
      final char = String.fromCharCode(c);
      if (char == '=') break;
      final val = chars.indexOf(char);
      if (val < 0) continue;
      buffer = (buffer << 6) | val;
      bitsLeft += 6;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        bytes.add((buffer >> bitsLeft) & 0xFF);
      }
    }
    return bytes;
  }

  // Parser JSON simple pour extraire roles, username, name
  static Map<String, dynamic> _parseSimpleJson(String json) {
    final result = <String, dynamic>{};
    try {
      // Extraire "roles": ["ROLE_..."]
      final rolesMatch =
          RegExp(r'"roles"\s*:\s*\[([^\]]*)\]').firstMatch(json);
      if (rolesMatch != null) {
        final rolesRaw = rolesMatch.group(1) ?? '';
        final roles = RegExp(r'"([^"]+)"')
            .allMatches(rolesRaw)
            .map((m) => m.group(1)!)
            .toList();
        result['roles'] = roles;
      }

      // Extraire "username": "..."
      final userMatch =
          RegExp(r'"username"\s*:\s*"([^"]+)"').firstMatch(json);
      if (userMatch != null) {
        result['username'] = userMatch.group(1);
      }

      // Extraire "name": "..."
      final nameMatch =
          RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(json);
      if (nameMatch != null) {
        result['name'] = nameMatch.group(1);
      }

      // Extraire "email": "..."
      final emailMatch =
          RegExp(r'"email"\s*:\s*"([^"]+)"').firstMatch(json);
      if (emailMatch != null) {
        result['email'] = emailMatch.group(1);
      }
    } catch (_) {}
    return result;
  }

  // ── Retourner le label lisible du rôle ────────────────────────
  static String roleLabel(String role) {
    switch (role) {
      case 'ROLE_ADMIN':
        return 'Administrateur';
      case 'ROLE_MANAGER':
        return 'Manager';
      case 'ROLE_TELLER':
        return 'Caissier';
      case 'ROLE_WAITER':
        return 'Serveur';
      default:
        return role;
    }
  }

  // ── Couleur associée au rôle ─────────────────────────────────
  static String roleColorHex(String role) {
    switch (role) {
      case 'ROLE_ADMIN':
        return '#D32F2F'; // rouge
      case 'ROLE_MANAGER':
        return '#F57C00'; // orange
      case 'ROLE_TELLER':
        return '#1976D2'; // bleu
      case 'ROLE_WAITER':
        return '#388E3C'; // vert
      default:
        return '#757575';
    }
  }
}