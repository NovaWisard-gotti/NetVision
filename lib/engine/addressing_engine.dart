/// Motor centralizado de cálculos IPv4.
///
/// Toda la lógica de direccionamiento vive aquí (nunca dentro de widgets),
/// según la regla de arquitectura del proyecto. Trabaja sobre enteros de
/// 32 bits para garantizar cálculos correctos de red, broadcast, rango de
/// hosts y comparación de subredes.
class AddressingEngine {
  const AddressingEngine._();

  /// Convierte "192.168.1.10" -> entero de 32 bits. Lanza [FormatException]
  /// si la cadena no es una IPv4 válida.
  static int ipToInt(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length != 4) {
      throw const FormatException('La dirección debe tener 4 octetos.');
    }
    var result = 0;
    for (final p in parts) {
      if (p.isEmpty || !RegExp(r'^\d+$').hasMatch(p)) {
        throw const FormatException('Cada octeto debe ser numérico.');
      }
      final value = int.parse(p);
      if (value < 0 || value > 255) {
        throw const FormatException('Cada octeto debe estar entre 0 y 255.');
      }
      result = (result << 8) | value;
    }
    return result;
  }

  static String intToIp(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ].join('.');
  }

  /// Valida sintácticamente una IPv4. No verifica si es de red/broadcast.
  static bool isValidIpv4(String ip) {
    try {
      ipToInt(ip);
      return true;
    } on FormatException {
      return false;
    }
  }

  static bool isValidPrefix(int prefixLength) =>
      prefixLength >= 0 && prefixLength <= 32;

  /// Valida que una máscara en formato decimal punteado (255.255.255.0) sea
  /// una máscara contigua válida y devuelve el prefijo equivalente, o null
  /// si no es válida.
  static int? maskToPrefix(String mask) {
    if (!isValidIpv4(mask)) return null;
    final value = ipToInt(mask);
    // Una máscara válida es una secuencia de 1s seguida de una de 0s.
    var seenZero = false;
    var ones = 0;
    for (var i = 31; i >= 0; i--) {
      final bit = (value >> i) & 1;
      if (bit == 1) {
        if (seenZero) return null;
        ones++;
      } else {
        seenZero = true;
      }
    }
    return ones;
  }

  static String prefixToMask(int prefixLength) {
    if (prefixLength == 0) return '0.0.0.0';
    final value = (0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF;
    return intToIp(value);
  }

  static int _networkMaskInt(int prefixLength) {
    if (prefixLength == 0) return 0;
    return (0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF;
  }

  static String networkAddress(String ip, int prefixLength) {
    final ipInt = ipToInt(ip);
    final maskInt = _networkMaskInt(prefixLength);
    return intToIp(ipInt & maskInt);
  }

  static String broadcastAddress(String ip, int prefixLength) {
    final ipInt = ipToInt(ip);
    final maskInt = _networkMaskInt(prefixLength);
    final wildcard = (~maskInt) & 0xFFFFFFFF;
    return intToIp((ipInt & maskInt) | wildcard);
  }

  /// Devuelve (primerHostUtilizable, ultimoHostUtilizable). Para prefijos
  /// /31 y /32 no hay hosts utilizables en el sentido clásico; se devuelve
  /// null en ese caso (fuera del alcance educativo del MVP).
  static (String, String)? usableHostRange(String ip, int prefixLength) {
    if (prefixLength >= 31) return null;
    final networkInt = ipToInt(networkAddress(ip, prefixLength));
    final broadcastInt = ipToInt(broadcastAddress(ip, prefixLength));
    if (broadcastInt - networkInt < 2) return null;
    return (intToIp(networkInt + 1), intToIp(broadcastInt - 1));
  }

  static int totalHosts(int prefixLength) {
    if (prefixLength >= 31) return 0;
    return (1 << (32 - prefixLength)) - 2;
  }

  static bool sameSubnet(String ipA, int prefixA, String ipB, int prefixB) {
    if (prefixA != prefixB) {
      // Con prefijos distintos, se comparan contra el prefijo más largo
      // (más específico), que es el criterio real de decisión IP.
      final longer = prefixA > prefixB ? prefixA : prefixB;
      return networkAddress(ipA, longer) == networkAddress(ipB, longer) &&
          prefixA == prefixB;
    }
    return networkAddress(ipA, prefixA) == networkAddress(ipB, prefixA);
  }

  static bool isWithinSubnet(String candidateIp, String networkIp, int prefixLength) {
    return networkAddress(candidateIp, prefixLength) ==
        networkAddress(networkIp, prefixLength);
  }

  /// Divide una red en [subnetCount] subredes de igual tamaño (VLSM
  /// uniforme). Devuelve la lista de (direcciónRed, nuevoPrefijo). Lanza
  /// [ArgumentError] si no es posible con el prefijo original.
  static List<(String network, int prefix)> divideIntoSubnets(
    String baseNetwork,
    int basePrefix,
    int subnetCount,
  ) {
    if (subnetCount < 1) {
      throw ArgumentError('El número de subredes debe ser al menos 1.');
    }
    final bitsNeeded = (subnetCount > 1) ? (subnetCount - 1).bitLength : 0;
    final newPrefix = basePrefix + bitsNeeded;
    if (newPrefix > 30) {
      throw ArgumentError(
          'No es posible crear $subnetCount subredes útiles a partir de un /$basePrefix.');
    }
    final blockSize = 1 << (32 - newPrefix);
    final baseInt = ipToInt(networkAddress(baseNetwork, basePrefix));
    final result = <(String, int)>[];
    for (var i = 0; i < subnetCount; i++) {
      result.add((intToIp(baseInt + i * blockSize), newPrefix));
    }
    return result;
  }
}
