import 'package:flutter_test/flutter_test.dart';
import 'package:netvision/engine/addressing_engine.dart';

void main() {
  group('AddressingEngine', () {
    test('ipToInt / intToIp son inversas', () {
      final value = AddressingEngine.ipToInt('192.168.1.10');
      expect(AddressingEngine.intToIp(value), '192.168.1.10');
    });

    test('valida direcciones IPv4', () {
      expect(AddressingEngine.isValidIpv4('192.168.1.10'), true);
      expect(AddressingEngine.isValidIpv4('256.1.1.1'), false);
      expect(AddressingEngine.isValidIpv4('192.168.1'), false);
    });

    test('calcula dirección de red y broadcast correctamente', () {
      expect(AddressingEngine.networkAddress('192.168.1.130', 24), '192.168.1.0');
      expect(AddressingEngine.broadcastAddress('192.168.1.130', 24), '192.168.1.255');
    });

    test('calcula el rango de hosts utilizables', () {
      final range = AddressingEngine.usableHostRange('192.168.1.0', 24);
      expect(range, isNotNull);
      expect(range!.$1, '192.168.1.1');
      expect(range.$2, '192.168.1.254');
    });

    test('determina si dos direcciones están en la misma subred', () {
      expect(AddressingEngine.sameSubnet('192.168.1.10', 24, '192.168.1.200', 24), true);
      expect(AddressingEngine.sameSubnet('192.168.1.10', 24, '192.168.2.10', 24), false);
    });

    group('sameSubnet con prefijos asimétricos', () {
      test('mismo prefijo, misma red -> true', () {
        expect(AddressingEngine.sameSubnet('192.168.1.10', 24, '192.168.1.20', 24), true);
      });

      test('mismo prefijo, redes distintas -> false', () {
        expect(AddressingEngine.sameSubnet('192.168.1.10', 24, '192.168.2.10', 24), false);
      });

      test('prefijos distintos pero ambos extremos caen en el mismo bloque más específico -> true', () {
        // 192.168.1.10/24 y 192.168.1.20/25: ambas direcciones están dentro
        // de 192.168.1.0/25 (el prefijo más específico), así que se
        // consideran la misma red.
        expect(AddressingEngine.sameSubnet('192.168.1.10', 24, '192.168.1.20', 25), true);
      });

      test('prefijos distintos y asimetría real -> false', () {
        // 192.168.1.200 cae en el bloque superior de un /25
        // (192.168.1.128/25), mientras que 192.168.1.20 cae en el bloque
        // inferior (192.168.1.0/25): bajo el prefijo más específico (/25)
        // no coinciden, así que no son la misma red.
        expect(AddressingEngine.sameSubnet('192.168.1.200', 24, '192.168.1.20', 25), false);
      });

      test('no es una simple comparación de igualdad de prefijos', () {
        // Antes de la corrección, cualquier par con prefijos distintos
        // devolvía siempre false por una condición contradictoria. Este caso
        // (10.0.0.4/8 y 10.0.0.6/30, ambos dentro del mismo bloque /30
        // 10.0.0.4-10.0.0.7) confirma que ya no ocurre.
        expect(AddressingEngine.sameSubnet('10.0.0.4', 8, '10.0.0.6', 30), true);
      });
    });

    test('divide una red en subredes iguales', () {
      final subnets = AddressingEngine.divideIntoSubnets('192.168.0.0', 24, 4);
      expect(subnets.length, 4);
      expect(subnets[0].$1, '192.168.0.0');
      expect(subnets[0].$2, 26);
      expect(subnets[1].$1, '192.168.0.64');
      expect(subnets[2].$1, '192.168.0.128');
      expect(subnets[3].$1, '192.168.0.192');
    });

    test('maskToPrefix reconoce máscaras válidas e inválidas', () {
      expect(AddressingEngine.maskToPrefix('255.255.255.0'), 24);
      expect(AddressingEngine.maskToPrefix('255.255.255.128'), 25);
      expect(AddressingEngine.maskToPrefix('255.0.255.0'), null);
    });

    test('bitsNeededForSubnetCount calcula los bits y subredes reales generadas', () {
      // 3 subredes solicitadas -> se necesitan 2 bits -> en realidad genera 4.
      expect(AddressingEngine.bitsNeededForSubnetCount(3), 2);
      expect(AddressingEngine.bitsNeededForSubnetCount(4), 2);
      expect(AddressingEngine.bitsNeededForSubnetCount(1), 0);
      expect(AddressingEngine.bitsNeededForSubnetCount(5), 3);
    });

    test('funciones de red lanzan errores claros con datos inválidos en vez de fallar silenciosamente', () {
      expect(() => AddressingEngine.ipToInt('no-es-una-ip'), throwsFormatException);
      expect(() => AddressingEngine.networkAddress('192.168.1.1', 99), throwsArgumentError);
      expect(() => AddressingEngine.divideIntoSubnets('192.168.0.0', 24, 0), throwsArgumentError);
    });
  });
}
