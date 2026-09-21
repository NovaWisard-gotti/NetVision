/// Contenido de la Consulta rápida: explicaciones breves, no un libro
/// digital. Cada entrada resume un concepto en pocas líneas.
class QuickReferenceEntry {
  final String term;
  final String explanation;
  const QuickReferenceEntry(this.term, this.explanation);
}

const List<QuickReferenceEntry> quickReferenceEntries = [
  QuickReferenceEntry('LAN', 'Red de área local: un conjunto de dispositivos conectados dentro de un mismo espacio físico, capaces de comunicarse sin salir a otra red.'),
  QuickReferenceEntry('Dirección IP', 'Identificador numérico de 32 bits (IPv4) que permite localizar un dispositivo dentro de una red.'),
  QuickReferenceEntry('Máscara / Prefijo', 'Define qué parte de la dirección IP corresponde a la red y cuál a los hosts. Se expresa como decimal punteado (255.255.255.0) o como prefijo (/24).'),
  QuickReferenceEntry('CIDR', 'Notación que combina una dirección de red con su prefijo, por ejemplo 192.168.1.0/24.'),
  QuickReferenceEntry('Gateway', 'Dirección del router al que un host envía el tráfico destinado a otras redes.'),
  QuickReferenceEntry('Switch', 'Dispositivo de capa 2 que conecta equipos dentro de una misma red local y reenvía tramas según direcciones MAC.'),
  QuickReferenceEntry('Router', 'Dispositivo que conecta redes diferentes y decide, mediante una tabla de rutas, por dónde reenviar cada paquete.'),
  QuickReferenceEntry('ARP', 'Proceso mediante el cual un dispositivo descubre la dirección física (MAC) correspondiente a una IP dentro de su misma red local.'),
  QuickReferenceEntry('DHCP', 'Servicio que asigna automáticamente dirección IP, máscara, gateway y DNS a los dispositivos de una red.'),
  QuickReferenceEntry('DNS', 'Servicio que traduce nombres de dominio (como portal.universidad.test) a direcciones IP.'),
  QuickReferenceEntry('Routing', 'Proceso de decidir el camino que debe seguir un paquete para llegar desde una red origen hasta una red destino.'),
];
