import 'dart:collection';

import 'package:rune/asm/asm.dart';

/// Tracks free registers for the use of a single computation involving many
/// registers.
class Registers {
  var _data = Queue<DirectDataRegister>.of({d0, d1, d2, d3, d4, d5, d6, d7});
  var _address = Queue<DirectAddressRegister>.of({a0, a1, a2, a3, a4, a5, a6});

  void releaseAddress(DirectAddressRegister a) {
    if (!_address.contains(a)) {
      _address.add(a);
    }
  }

  void releaseData(DirectDataRegister d) {
    if (!_data.contains(d)) {
      _data.add(d);
    }
  }

  void releaseAll() {
    _data = Queue<DirectDataRegister>.of({d0, d1, d2, d3, d4, d5, d6, d7});
    _address = Queue<DirectAddressRegister>.of({a0, a1, a2, a3, a4, a5, a6});
  }

  bool addressUsed(DirectAddressRegister a) {
    return !_address.contains(a);
  }

  bool dataUsed(DirectDataRegister d) {
    return !_data.contains(d);
  }

  Asm moveToData(Size size, DirectAddressRegister a,
      {List<DirectDataRegister> preferring = const []}) {
    releaseAddress(a);
    var d = data(preferring: preferring);
    return switch (size) {
      byte => move.b(a, d),
      word => move.w(a, d),
      long => move.l(a, d),
    };
  }

  DirectAddressRegister address(
      {List<DirectAddressRegister> preferring = const []}) {
    var a = tryAddress(preferring: preferring);
    if (a == null) {
      throw StateError('no free address registers');
    }
    return a;
  }

  DirectAddressRegister? tryAddress(
      {List<DirectAddressRegister> preferring = const []}) {
    for (var pref in preferring) {
      if (_address.remove(pref)) return pref;
    }
    if (_address.isEmpty) return null;
    return _address.removeFirst();
  }

  DirectDataRegister data({List<DirectDataRegister> preferring = const []}) {
    var d = tryData(preferring: preferring);
    if (d == null) {
      throw StateError('no free data registers');
    }
    return d;
  }

  /// Returns a free data register, but considers it still free.
  DirectDataRegister temporaryData() {
    if (_data.isEmpty) throw StateError('no free data registers');
    return _data.first;
  }

  DirectDataRegister? tryData(
      {List<DirectDataRegister> preferring = const []}) {
    for (var pref in preferring) {
      if (_data.remove(pref)) return pref;
    }
    if (_data.isEmpty) return null;
    return _data.removeFirst();
  }
}
