// ignore_for_file: avoid_print

import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/harvest_model.dart';

class StorageService {
  // Singleton
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Cajas (Tablas) de Hive
  static const String boxHarvests = 'harvestsBox';
  //static const String boxProducers = 'producersBox';

  static Future<void> initialize() async {
    // Inicializa Hive
    await Hive.initFlutter();

    // Aqui registraremos los adaptadores más tarde (cuando creemos los modelos)
    // Hive.registerAdapter(ProducerModelAdapter());
    Hive.registerAdapter(HarvestModelAdapter()); // Esto permite guardar objetos HarvestModel directamente

    // Abrir las cajas para que estén listas
    //await Hive.openBox(boxProducers);
    await Hive.openBox<HarvestModel>(boxHarvests);
    print("💾 Hive iniciada y Adaptador de Cosechas registrado");
  }
  // Helper para obtener la caja ya tipada
  Box<HarvestModel> get harvestBox => Hive.box<HarvestModel>(boxHarvests);
}