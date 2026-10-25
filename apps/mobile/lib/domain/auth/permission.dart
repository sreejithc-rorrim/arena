/// Staff/owner permissions (design: PERMS). A user is an **owner** when they
/// hold `money` or `reports` — that unlocks the owner areas (Money, Reports,
/// Settings, pricing) and makes Today their home; otherwise they are **staff**
/// and land on the Floor.
library;

enum Permission {
  start('start', 'Start sessions'),
  bill('bill', 'Bill'),
  discount('discount', 'Give discounts'),
  members('members', 'Manage members'),
  stations('stations', 'Manage stations'),
  money('money', 'Money'),
  reports('reports', 'Reports'),
  settings('settings', 'Settings'),
  billEdit('bill_edit', 'Edit own bills'),
  billRecord('bill_record', 'Add missed bills');

  const Permission(this.code, this.label);

  final String code;
  final String label;

  static Permission? fromCode(String code) {
    for (final p in values) {
      if (p.code == code) return p;
    }
    return null;
  }

  static Set<Permission> parse(Iterable<String> codes) =>
      {for (final c in codes) fromCode(c)}.whereType<Permission>().toSet();

  static List<String> codesOf(Iterable<Permission> perms) =>
      [for (final p in perms) p.code];

  /// Every permission — the owner's full set.
  static Set<Permission> get all => values.toSet();
}
