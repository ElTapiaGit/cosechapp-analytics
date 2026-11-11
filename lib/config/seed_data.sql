-- REINICIO DE DATOS PARA DEMOSTRACIÓN
TRUNCATE TABLE harvest_records, producers, zones RESTART IDENTITY CASCADE;

-- CARGAR ZONAS DE PRUEBA
INSERT INTO zones (name) VALUES ('ZONA_ALFA'), ('ZONA_BETA'), ('ZONA_GAMA') ON CONFLICT (name) DO NOTHING;

-- CARGAR PRODUCTORES SIMULADOS
INSERT INTO producers (full_name, zone_id) VALUES
('PRODUCTOR_01', (SELECT id FROM zones WHERE name = 'ZONA_ALFA')),
('PRODUCTOR_02', (SELECT id FROM zones WHERE name = 'ZONA_ALFA')),
('PRODUCTOR_03', (SELECT id FROM zones WHERE name = 'ZONA_BETA')),
('PRODUCTOR_04', (SELECT id FROM zones WHERE name = 'ZONA_GAMA'))
ON CONFLICT (full_name, zone_id) DO NOTHING;

-- CARGAR HISTORIAL DE COSECHAS DE EJEMPLO
INSERT INTO harvest_records 
(dcto_code, producer_id, quantity_rejected, quantity_received, quantity_processed, cut_date, processed_date, programmer, transport_driver, status, next_estimated_date)
VALUES
('1001', (SELECT id FROM producers WHERE full_name = 'PRODUCTOR_01' AND zone_id = (SELECT id FROM zones WHERE name = 'ZONA_ALFA')), 45, 2500, 2500, '2026-01-10', '2026-01-11', 'EXT_01', 'CHOFER_A', 'HARVESTED', '2026-01-10'::date + interval '4 months'),
('1002', (SELECT id FROM producers WHERE full_name = 'PRODUCTOR_02' AND zone_id = (SELECT id FROM zones WHERE name = 'ZONA_ALFA')), 12, 1800, 1800, '2026-01-12', '2026-01-13', 'EXT_01', 'CHOFER_A', 'HARVESTED', '2026-01-12'::date + interval '4 months'),
('1003', (SELECT id FROM producers WHERE full_name = 'PRODUCTOR_03' AND zone_id = (SELECT id FROM zones WHERE name = 'ZONA_BETA')), 0, 3200, 3200, '2026-01-15', '2026-01-16', 'EXT_02', 'CHOFER_B', 'HARVESTED', '2026-01-15'::date + interval '4 months');