import 'package:flutter/material.dart';

/// Ícone ilustrativo de cada tipo de área (lado direito do cartão no Figma).
IconData areaTypeIcon(String type) => switch (type) {
      'producao' => Icons.factory_outlined,
      'armazem' => Icons.warehouse_outlined,
      'caldeira' => Icons.local_fire_department_outlined,
      'laboratorio' => Icons.science_outlined,
      'escritorio' => Icons.apartment_outlined,
      'tanques' => Icons.propane_tank_outlined,
      'expedicao' => Icons.local_shipping_outlined,
      'tratamento' => Icons.water_outlined,
      _ => Icons.domain_outlined,
    };
