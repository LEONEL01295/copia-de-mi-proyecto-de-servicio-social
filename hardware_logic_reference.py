from machine import Pin, I2C
import time

# Inicializar I2C
i2c = I2C(0, scl=Pin(5), sda=Pin(4))

# -------------------------------------------------------------------------
# CONFIGURACIÓN DE ESTADOS DE LA SECUENCIA MAESTRA UNIFICADA
# -------------------------------------------------------------------------
EST_M4_ABRIR_1        = 1
EST_M2_ATRAS_1        = 2
EST_M2_ADELANTE_55    = 3
EST_M3_SUBIR_1        = 4
EST_M1_IZQ_75         = 5
EST_M1_IZQ_75         = 5
EST_M3_BAJAR_1        = 6
EST_M4_CERRAR_1       = 7
EST_M3_SUBIR_2        = 8
EST_M1_DER_25         = 9

# --- PASOS ELIMINADOS DE RECORRIDO INTERMEDIO ---
# Se salta directo al paso de bajar el brazo
EST_M3_BAJAR_2        = 12
EST_M4_ABRIR_ESPERA   = 13

# --- NUEVOS ESTADOS DE PRENSADO INTEGRADOS ---
EST_PRENSA_ALINEAR    = 14
EST_PRENSA_EST1       = 15
EST_PRENSA_EST2       = 16
EST_PRENSA_EST3       = 17
EST_PRENSA_EST4       = 18

# --- CONTINUACIÓN Y CIERRE DEL BRAZO ---
EST_M4_CERRAR_2       = 19
EST_M3_SUBIR_3        = 20
EST_M1_DER_50         = 21
EST_M3_BAJAR_3        = 22
EST_M4_ABRIR_FINAL    = 23
EST_FIN_DEFINITIVO    = 24

estado = EST_M4_ABRIR_1

# -------------------------------------------------------------------------
# MÁSCARAS DE SENSADO - BRAZO (DIRECCIÓN I2C: 0x21)
# -------------------------------------------------------------------------
MASK_S1 = 0b00000010  # M1: Pulsos de la base
MASK_S3 = 0b00000100  # M2: Pulsos del brazo
MASK_S4 = 0b00001000  # M2: Tope/Referencia hacia atrás
MASK_S7 = 0b01000000  # M4: Pulsos de la pinza
MASK_S8 = 0b10000000  # M4: Tope/Referencia de pinza abierta

# -------------------------------------------------------------------------
# CONFIGURACIÓN Y MÁSCARAS - PRENSA (DIRECCIÓN I2C: 0x22)
# -------------------------------------------------------------------------
btm_est1 = 0b00000011  # Espera P1 y S1 (Valor 5)
btm_est2 = 0b00000001  # Espera P2 y S1 (Valor 6)
btm_est3 = 0b00001011  # Espera P2 y S2 (Valor 10)
btm_est4 = 0b00000111  # Espera P2 y S1 (Valor 6)
MASCARA_ORIGEN = 0b00000100  # Sensor de alineación S1 de la prensa

# Variables globales de control
contador_pulsos = 0
ultimo_pulso = 0
motor_inicializado = False
tiempo_inicio = 0

# Asegurar apagado inicial de TODAS las tarjetas de relevadores
i2c.writeto(0x24, bytes([0b11111111])) # Apagar brazo
i2c.writeto(0x25, bytes([0b11111111])) # Apagar prensa y banda
time.sleep(0.5)

print("--- CELDA DE MANUFACTURA UNIFICADA INICIADA ---")

# -------------------------------------------------------------------------
# BUCLE PRINCIPAL DE EJECUCIÓN
# -------------------------------------------------------------------------
while True:
    try:
        # =================================================================
        # PASO 1: VERIFICAR Y/O ABRIR PINZA (M4)
        # =================================================================
        if estado == EST_M4_ABRIR_1:
            if not motor_inicializado:
                lectura = i2c.readfrom(0x21, 1)[0]
                if (lectura & MASK_S8) != 0:
                    print("Paso 1: La pinza (M4) YA está abierta. Saltando al Paso 2...")
                    estado = EST_M2_ATRAS_1
                    continue
                else:
                    print("Paso 1: Abriendo pinza (M4) buscando S8...")
                    i2c.writeto(0x24, bytes([0b11111101]))
                    motor_inicializado = True

            if motor_inicializado:
                lectura = i2c.readfrom(0x21, 1)[0]
                if (lectura & MASK_S8) != 0:
                    print("¡Tope S8 alcanzado! Deteniendo pinza.")
                    i2c.writeto(0x24, bytes([0b11111111]))
                    time.sleep(0.5)
                    estado = EST_M2_ATRAS_1
                    motor_inicializado = False

        # =================================================================
        # PASO 2: MOVER M2 HACIA ATRÁS HASTA EL TOPE
        # =================================================================
        elif estado == EST_M2_ATRAS_1:
            if not motor_inicializado:
                print("Paso 2: Moviendo M2 ATRÁS buscando tope S4...")
                i2c.writeto(0x24, bytes([0b11101111]))
                motor_inicializado = True

            lectura = i2c.readfrom(0x21, 1)[0]
            if (lectura & MASK_S4) != 0:
                print("¡Tope S4 alcanzado! Deteniendo M2.")
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M2_ADELANTE_55
                motor_inicializado = False

        # =================================================================
        # PASO 3: MOVER M2 HACIA ADELANTE (55 PULSOS)
        # =================================================================
        elif estado == EST_M2_ADELANTE_55:
            if not motor_inicializado:
                print("Paso 3: Moviendo M2 ADELANTE por 55 pulsos...")
                i2c.writeto(0x24, bytes([0b11011111]))
                lectura_inicial = i2c.readfrom(0x21, 1)[0]
                ultimo_pulso = 1 if (lectura_inicial & MASK_S3) else 0
                contador_pulsos = 0
                motor_inicializado = True

            lectura = i2c.readfrom(0x21, 1)[0]
            pulso_actual = 1 if (lectura & MASK_S3) else 0

            if pulso_actual == 1 and ultimo_pulso == 0:
                contador_pulsos += 1
                print(f"[M2-ADELANTE] Pulsos: {contador_pulsos} / 55")

            ultimo_pulso = pulso_actual
            if contador_pulsos >= 68:
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M3_SUBIR_1
                motor_inicializado = False

        # =================================================================
        # PASO 4: SUBIR M3 HASTA SENSOR REPETIBLE (VALOR 119)
        # =================================================================
        elif estado == EST_M3_SUBIR_1:
            if not motor_inicializado:
                print("Paso 4: M3 SUBIENDO... Esperando lectura 119.")
                i2c.writeto(0x24, bytes([0b11110111]))
                tiempo_inicio = time.ticks_ms()
                motor_inicializado = True

            lectura_actual = i2c.readfrom(0x21, 1)[0]
            tiempo_transcurrido = time.ticks_diff(time.ticks_ms(), tiempo_inicio)

            if lectura_actual == 119 or tiempo_transcurrido >= 3000:
                print("¡Sensor M3 superior alcanzado! Deteniendo brazo arriba.")
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M1_IZQ_75
                motor_inicializado = False

        # =================================================================
        # PASO 5: MOVER BASE (M1) A LA IZQUIERDA (75 PULSOS)
        # =================================================================
        elif estado == EST_M1_IZQ_75:
            if not motor_inicializado:
                print("Paso 5: Moviendo M1 IZQUIERDA por 75 pulsos...")
                i2c.writeto(0x24, bytes([0b01111111]))
                lectura_inicial = i2c.readfrom(0x21, 1)[0]
                ultimo_pulso = 1 if (lectura_inicial & MASK_S1) else 0
                contador_pulsos = 0
                motor_inicializado = True

            lectura = i2c.readfrom(0x21, 1)[0]
            pulso_actual = 1 if (lectura & MASK_S1) else 0

            if pulso_actual == 1 and ultimo_pulso == 0:
                contador_pulsos += 1
                print(f"[M1-IZQ] Pulsos: {contador_pulsos} / 75")

            ultimo_pulso = pulso_actual
            if contador_pulsos >= 75:
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M3_BAJAR_1
                motor_inicializado = False

        # =================================================================
        # PASO 6: BAJAR M3 POR TIEMPO EXACTO (2900 ms)
        # =================================================================
        elif estado == EST_M3_BAJAR_1:
            if not motor_inicializado:
                print("Paso 6: M3 BAJANDO por 2.9 segundos...")
                i2c.writeto(0x24, bytes([0b11111011]))
                tiempo_inicio = time.ticks_ms()
                motor_inicializado = True

            tiempo_transcurrido = time.ticks_diff(time.ticks_ms(), tiempo_inicio)
            if tiempo_transcurrido >= 2900:
                print("¡Tiempo de bajada completado! Deteniendo brazo.")
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M4_CERRAR_1
                motor_inicializado = False

        # =================================================================
        # PASO 7: CERRAR PINZA (M4) POR PULSOS (7 PULSOS)
        # =================================================================
        elif estado == EST_M4_CERRAR_1:
            if not motor_inicializado:
                print("Paso 7: Cerrando pinza (M4) por 7 pulsos para sujetar pieza...")
                i2c.writeto(0x24, bytes([0b11111110]))
                lectura_inicial = i2c.readfrom(0x21, 1)[0]
                ultimo_pulso = 1 if (lectura_inicial & MASK_S7) else 0
                contador_pulsos = 0
                motor_inicializado = True

            lectura = i2c.readfrom(0x21, 1)[0]
            pulso_actual = 1 if (lectura & MASK_S7) else 0

            if pulso_actual == 1 and ultimo_pulso == 0:
                contador_pulsos += 1
                print(f"[M4-CERRAR] Pulsos: {contador_pulsos} / 7")

            ultimo_pulso = pulso_actual
            if contador_pulsos >= 7:
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M3_SUBIR_2
                motor_inicializado = False

        # =================================================================
        # PASO 8: SUBIR M3 POR COMPLETO ANTES DE MOVER LA BASE
        # =================================================================
        elif estado == EST_M3_SUBIR_2:
            if not motor_inicializado:
                print("Paso 8: M3 SUBIENDO por completo... Esperando lectura 119.")
                i2c.writeto(0x24, bytes([0b11110111]))
                tiempo_inicio = time.ticks_ms()
                motor_inicializado = True

            lectura_actual = i2c.readfrom(0x21, 1)[0]
            tiempo_transcurrido = time.ticks_diff(time.ticks_ms(), tiempo_inicio)

            if lectura_actual == 119 or tiempo_transcurrido >= 3000:
                print("¡Sensor M3 alcanzado! Brazo arriba seguro.")
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M1_DER_25
                motor_inicializado = False

        # =================================================================
        # PASO 9: MOVER BASE (M1) A LA DERECHA (25 PULSOS)
        # =================================================================
        elif estado == EST_M1_DER_25:
            if not motor_inicializado:
                print("Paso 9: Moviendo M1 DERECHA por 25 pulses...")
                i2c.writeto(0x24, bytes([0b10111111]))
                lectura_inicial = i2c.readfrom(0x21, 1)[0]
                ultimo_pulso = 1 if (lectura_inicial & MASK_S1) else 0
                contador_pulsos = 0
                motor_inicializado = True

            lectura = i2c.readfrom(0x21, 1)[0]
            pulso_actual = 1 if (lectura & MASK_S1) else 0

            if pulso_actual == 1 and ultimo_pulso == 0:
                contador_pulsos += 1
                print(f"[M1-DER] Pulsos: {contador_pulsos} / 25")

            ultimo_pulso = pulso_actual
            if contador_pulsos >= 25:
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                # MODIFICACIÓN: Saltamos directo a bajar el brazo (Paso 12) sin pasar por atrás/adelante
                estado = EST_M3_BAJAR_2
                motor_inicializado = False

        # =================================================================
        # PASO 12: BAJAR M3 POR TIEMPO (2900 ms) - DIRECTO DESPUÉS DE LOS 25 PULSOS
        # =================================================================
        elif estado == EST_M3_BAJAR_2:
            if not motor_inicializado:
                print("Paso 12: M3 BAJANDO por 2.9 segundos para dejar la pieza...")
                i2c.writeto(0x24, bytes([0b11111011]))
                tiempo_inicio = time.ticks_ms()
                motor_inicializado = True

            tiempo_transcurrido = time.ticks_diff(time.ticks_ms(), tiempo_inicio)
            if tiempo_transcurrido >= 2700:
                print("¡Tiempo de bajada completado!")
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M4_ABRIR_ESPERA
                motor_inicializado = False

        # =================================================================
        # PASO 13: ABRIR PINZA (M4) Y DEJARLA ABIERTA
        # =================================================================
        elif estado == EST_M4_ABRIR_ESPERA:
            if not motor_inicializado:
                print("Paso 13: Abriendo pinza (M4) buscando S8...")
                i2c.writeto(0x24, bytes([0b11111101]))
                motor_inicializado = True

            lectura = i2c.readfrom(0x21, 1)[0]
            if (lectura & MASK_S8) != 0:
                print("¡Tope S8 alcanzado! Pinza abierta.")
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)

                print("\n======================================================")
                print(" >>> CEDER CONTROL: INICIANDO PROCESO DE PRENSADO <<< ")
                print("======================================================")
                estado = EST_PRENSA_ALINEAR
                motor_inicializado = False

        # =================================================================
        # PASO 14: PRENSA - ALINEACIÓN DE ENTRADA (S1 ARRIBA)
        # =================================================================
        elif estado == EST_PRENSA_ALINEAR:
            in0 = i2c.readfrom(0x22, 1)[0]
            origen_prensa = in0 & MASCARA_ORIGEN

            if origen_prensa == 4:
                print("Prensa alineada en Origen (Arriba). Iniciando rutina...")
                i2c.writeto(0x25, bytes([0b11111111]))
                time.sleep(1)
                estado = EST_PRENSA_EST1
                motor_inicializado = False
            else:
                if not motor_inicializado:
                    print("Alineando: Subiendo prensa a posición de origen S1...")
                    i2c.writeto(0x25, bytes([0b10111111])) # RLY01: Sube Prensa
                    motor_inicializado = True
                time.sleep(0.1)

        # =================================================================
        # PASO 15: PRENSA - ESTADO 1 (DETECTAR EN P1 Y ACTIVAR BANDA ADELANTE)
        # =================================================================
        elif estado == EST_PRENSA_EST1:
            in0 = i2c.readfrom(0x22, 1)[0]
            entr = in0 & btm_est1

            print("-> P1 detectó pieza. Encendiendo M2 Adelante.")
            i2c.writeto(0x25, bytes([0b11011111])) # RLY03: Banda Adelante
            time.sleep(5)
            estado = EST_PRENSA_EST2
            motor_inicializado = False

        # =================================================================
        # PASO 16: PRENSA - ESTADO 2 (ESPERAR LLEGADA A P2 / BAJAR PRENSA)
        # =================================================================
        elif estado == EST_PRENSA_EST2:
            if not motor_inicializado:
                print("Prensa Estado 2: Esperando que pieza llegue a P2...")
                motor_inicializado = True

            in0 = i2c.readfrom(0x22, 1)[0]
            entr2 = in0 & btm_est2

            if entr2 == 1:
                print("-> P2 detectó pieza. Parando Banda y Bajando Prensa M1.")
                i2c.writeto(0x25, bytes([0b11111111]))
                time.sleep(0.5)

                i2c.writeto(0x25, bytes([0b01111111])) # RLY02: Baja Prensa
                estado = EST_PRENSA_EST3
                motor_inicializado = False

        # =================================================================
        # PASO 17: PRENSA - ESTADO 3 (ESPERAR TOPE S2 DE BAJADA / SUBIR PRENSA)
        # =================================================================
        elif estado == EST_PRENSA_EST3:
            if not motor_inicializado:
                print("Prensa Estado 3: Esperando que prensa llegue a S2 (Abajo)...")
                motor_inicializado = True

            in0 = i2c.readfrom(0x22, 1)[0]
            entr3 = in0 & btm_est3

            if entr3 == 11:
                print("-> S2 detectado (Prensado hecho). Subiendo Prensa M1.")
                i2c.writeto(0x25, bytes([0b10111111])) # RLY01: Sube Prensa
                estado = EST_PRENSA_EST4
                motor_inicializado = False

        # =================================================================
        # PASO 18: PRENSA - ESTADO 4 (ESPERAR RETORNO S1 / REVERSA BANDA)
        # =================================================================
        elif estado == EST_PRENSA_EST4:
            if not motor_inicializado:
                print("Prensa Estado 4: Esperando que prensa regrese a S1 (Arriba)...")
                motor_inicializado = True

            in0 = i2c.readfrom(0x22, 1)[0]
            entr4 = in0 & btm_est4

            if entr4 == 7:
                print("-> S1 detectado. Prensa guardada. Encendiendo M2 ATRÁS (Retorno).")
                i2c.writeto(0x25, bytes([0b11101111])) # RLY04: Banda ATRÁS
                time.sleep(5)

                i2c.writeto(0x25, bytes([0b11111111])) # Detener banda
                time.sleep(2)

                print("\n=======================================================")
                print(" >>> RETORNO DE CONTROL: PROCESANDO PASOS DEL BRAZO <<<")
                print("=======================================================")
                estado = EST_M4_CERRAR_2 # Regresa el control al brazo para cerrar
                motor_inicializado = False

        # =================================================================
        # PASO 19: RETORNO BRAZO - CERRAR PINZA (M4) NUEVAMENTE (7 PULSOS)
        # =================================================================
        elif estado == EST_M4_CERRAR_2:
            if not motor_inicializado:
                print("Paso 19: Cerrando pinza (M4) por 7 pulsos sobre la pieza prensada...")
                i2c.writeto(0x24, bytes([0b11111110]))
                lectura_inicial = i2c.readfrom(0x21, 1)[0]
                ultimo_pulso = 1 if (lectura_inicial & MASK_S7) else 0
                contador_pulsos = 0
                motor_inicializado = True

            lectura = i2c.readfrom(0x21, 1)[0]
            pulso_actual = 1 if (lectura & MASK_S7) else 0

            if pulso_actual == 1 and ultimo_pulso == 0:
                contador_pulsos += 1
                print(f"[M4-CERRAR] Pulsos: {contador_pulsos} / 7")

            ultimo_pulso = pulso_actual
            if contador_pulsos >= 7:
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M3_SUBIR_3
                motor_inicializado = False

        # =================================================================
        # PASO 20: SUBIR M3 DESPUÉS DEL AGARRE SECUNDARIO
        # =================================================================
        elif estado == EST_M3_SUBIR_3:
            if not motor_inicializado:
                print("Paso 20: M3 SUBIENDO... Esperando lectura 119.")
                i2c.writeto(0x24, bytes([0b11110111]))
                tiempo_inicio = time.ticks_ms()
                motor_inicializado = True

            lectura_actual = i2c.readfrom(0x21, 1)[0]
            tiempo_transcurrido = time.ticks_diff(time.ticks_ms(), tiempo_inicio)

            if lectura_actual == 119 or tiempo_transcurrido >= 3000:
                print("¡Sensor M3 superior alcanzado! Deteniendo.")
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M1_DER_50
                motor_inicializado = False

        # =================================================================
        # PASO 21: MOVER BASE (M1) A LA DERECHA FINAL (50 PULSOS)
        # =================================================================
        elif estado == EST_M1_DER_50:
            if not motor_inicializado:
                print("Paso 21: Moviendo M1 DERECHA por 50 pulsos finales...")
                i2c.writeto(0x24, bytes([0b10111111]))
                lectura_inicial = i2c.readfrom(0x21, 1)[0]
                ultimo_pulso = 1 if (lectura_inicial & MASK_S1) else 0
                contador_pulsos = 0
                motor_inicializado = True

            lectura = i2c.readfrom(0x21, 1)[0]
            pulso_actual = 1 if (lectura & MASK_S1) else 0

            if pulso_actual == 1 and ultimo_pulso == 0:
                contador_pulsos += 1
                print(f"[M1-DER] Pulsos: {contador_pulsos} / 50")

            ultimo_pulso = pulso_actual
            if contador_pulsos >= 50:
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M3_BAJAR_3
                motor_inicializado = False

        # =================================================================
        # PASO 22: BAJAR M3 POR ÚLTIMA VEZ (2900 ms)
        # =================================================================
        elif estado == EST_M3_BAJAR_3:
            if not motor_inicializado:
                print("Paso 22: M3 BAJANDO final por 2.9 segundos...")
                i2c.writeto(0x24, bytes([0b11111011]))
                tiempo_inicio = time.ticks_ms()
                motor_inicializado = True

            tiempo_transcurrido = time.ticks_diff(time.ticks_ms(), tiempo_inicio)
            if tiempo_transcurrido >= 2700:
                print("¡Tiempo de bajada completado!")
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_M4_ABRIR_FINAL
                motor_inicializado = False

        # =================================================================
        # PASO 23: ABRIR PINZA FINAL
        # =================================================================
        elif estado == EST_M4_ABRIR_FINAL:
            if not motor_inicializado:
                print("Paso 23: Abriendo pinza (M4) final buscando S8...")
                i2c.writeto(0x24, bytes([0b11111101]))
                motor_inicializado = True

            lectura = i2c.readfrom(0x21, 1)[0]
            if (lectura & MASK_S8) != 0:
                print("¡Tope S8 alcanzado! Pinza abierta y lista en el destino.")
                i2c.writeto(0x24, bytes([0b11111111]))
                time.sleep(0.5)
                estado = EST_FIN_DEFINITIVO

        # =================================================================
        # PASO 24: FIN DEFINITIVO
        # =================================================================
        elif estado == EST_FIN_DEFINITIVO:
            print("\n=======================================================")
            print(" CICLO COMPLETO DE PROCESAMIENTO Y PRENSADO FINALIZADO ")
            print("=======================================================")
            break

    except OSError:
        pass

    time.sleep(0.002)

print("Sistema seguro y desenergizado por completo.")
