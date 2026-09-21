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
  });
}
