/// Helpers for the loose JSON the Express API returns.
///
/// The backend is inconsistent about identifiers: Prisma rows carry `id`, but
/// several controllers add an `_id` alias for the React frontend. Numbers may
/// arrive as int or double, and relations are sometimes an object and
/// sometimes a bare id string. These helpers absorb all of that.
library;

String idOf(Map<String, dynamic> json) =>
    (json['_id'] ?? json['id'] ?? '').toString();

String asString(dynamic value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

String? asStringOrNull(dynamic value) => value?.toString();

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

DateTime? asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

List<String> asStringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
}

List<int> asIntList(dynamic value) {
  if (value is List) return value.map((e) => asInt(e)).toList();
  return const [];
}

/// Relations arrive either populated (`{id, clubName}`) or as a raw id string.
/// Returns the id in both cases.
String? relationId(dynamic value) {
  if (value == null) return null;
  if (value is Map) return idOf(value.cast<String, dynamic>());
  return value.toString();
}

/// Lists come back either bare or wrapped (`{data: [...]}`, `{groups: [...]}`).
List<Map<String, dynamic>> asObjectList(dynamic value, {String? key}) {
  dynamic list = value;
  if (value is Map && key != null) list = value[key];
  if (value is Map && key == null) {
    list = value['data'] ?? value['results'] ?? value['items'];
  }
  if (list is List) {
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }
  return const [];
}
