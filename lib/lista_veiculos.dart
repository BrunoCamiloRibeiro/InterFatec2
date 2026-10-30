import 'package:flutter/material.dart';

class Veiculos extends StatefulWidget {
  const Veiculos({super.key});

  @override
  State<Veiculos> createState() => _VeiculosState();
}

class _VeiculosState extends State<Veiculos> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Lista de Veículos'),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red),
        child: ListView(
          children: [
            Card(
              elevation: 12,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 14,
                  children: [
                    // IDENTIFICAÇÃO E STATUS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // IDENTIFICAÇÃO
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'XXX-1234',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Marca Modelo · YYYY',
                              style: TextStyle(
                                fontSize: 14,
                                // fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  // IMPLEMENTAR MUDANÇA DE ÍCONE DE ACORDO COM TIPO
                                  size: 20,
                                  Icons.directions_car_outlined,
                                  color: Colors.grey[700],
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Tipo de Veículo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    // fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // STATUS
                        Column(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                // IMPLEMENTAR MUDANÇA DE STATUS?
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: Color.lerp(
                                      Colors.green,
                                      Colors.black,
                                      0.5,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Disponível',
                                    style: TextStyle(
                                      color: Color.lerp(
                                        Colors.green,
                                        Colors.black,
                                        0.5,
                                      ),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // INFORMAÇÕES OPERACIONAIS
                    Row(
                      spacing: 12,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 12,
                          children: [
                            // QUILOMETRAGEM E QTD DE ASSENTOS
                            Row(
                              children: [
                                // QUILOMETRAGEM
                                Row(
                                  children: [
                                    Icon(
                                      Icons.speed_outlined,
                                      size: 20,
                                      color: Colors.grey[700],
                                    ),
                                    SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Quilometragem Atual',
                                          style: TextStyle(
                                            color: Color.lerp(
                                              Colors.grey,
                                              Colors.black,
                                              0.5,
                                            ),
                                            fontSize: 12,
                                            // fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '67.670 km',
                                          style: TextStyle(
                                            fontSize: 14,
                                            // fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(width: 16),
                                // QTD DE ASSENTOS
                                Row(
                                  children: [
                                    Icon(
                                      Icons.chair_outlined,
                                      size: 20,
                                      color: Colors.grey[700],
                                    ),
                                    SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Qtd. de Assentos',
                                          style: TextStyle(
                                            color: Color.lerp(
                                              Colors.grey,
                                              Colors.black,
                                              0.5,
                                            ),
                                            fontSize: 12,
                                            // fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '67',
                                          style: TextStyle(
                                            fontSize: 14,
                                            // fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // ÚLTIMO MOTORISTA
                            Row(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline_outlined,
                                      size: 20,
                                      color: Colors.grey[700],
                                    ),
                                    SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Último Motorista',
                                          style: TextStyle(
                                            color: Color.lerp(
                                              Colors.grey,
                                              Colors.black,
                                              0.5,
                                            ),
                                            fontSize: 12,
                                            // fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Nome do Último Motorista',
                                          style: TextStyle(
                                            fontSize: 14,
                                            // fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    // TAGS / EXTRAS DO VEÍCULO
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () {}, // FUTURAMENTE fazer aplicar filtro pela tag
                          icon: Icon(Icons.ac_unit_outlined, size: 16),
                          label: Text('Ar-condicionado'),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            foregroundColor: Color.lerp(
                              Colors.blue,
                              Colors.black,
                              0.4,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            // shape: RoundedRectangleBorder(
                            //   borderRadius: BorderRadius.circular(8),
                            // ),
                          ),
                        ),
                      ],
                    ),
                    // BOTÕES DE EDITAR E VER DETALHES
                    Divider(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: TextButton(
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(
                                EdgeInsets.all(20),
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadiusGeometry.circular(
                                    8,
                                  ),
                                ),
                              ),
                            ),
                            onPressed: () {},
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 25,
                                  color: Colors.grey[700],
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Editar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color.lerp(
                                      Colors.grey,
                                      Colors.black,
                                      0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 100),
                        Expanded(
                          child: TextButton(
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(
                                EdgeInsets.all(20),
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadiusGeometry.circular(
                                    8,
                                  ),
                                ),
                              ),
                            ),
                            onPressed: () {},
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Ver Detalhes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color.lerp(
                                      Colors.grey,
                                      Colors.black,
                                      0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(
                                  Icons.arrow_forward_outlined,
                                  size: 25,
                                  color: Colors.grey[700],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
