from machine import Pin, I2C
import time

# I2C compartido
i2c = I2C(0, scl=Pin(5), sda=Pin(4))

# Direcciones I2C
DIRECCION_ENTRADAS = 0x21
DIRECCION_RELES    = 0x24

# Máscaras de Sensado
MASK_S1 = 0b00000010  # M1: Pulsos de la base
MASK_S3 = 0b00000100  # M2: Pulsos del brazo
MASK_S4 = 0b00001000  # M2: Tope/Referencia hacia atrás
MASK_S7 = 0b01000000  # M4: Pulsos de la pinza
MASK_S8 = 0b10000000  # M4: Tope/Referencia de pinza abierta

def apagar_todo():
    """Apaga todos los actuadores del robot"""
    i2c.writeto(DIRECCION_RELES, bytes([0b11111111]))

def controlar_actuador(rele_index, encender):
    """Control manual de un relé específico (0-7)"""
    try:
        actual = i2c.readfrom(DIRECCION_RELES, 1)[0]
        if encender:
            nuevo = actual & ~(1 << rele_index)
        else:
            nuevo = actual | (1 << rele_index)
        i2c.writeto(DIRECCION_RELES, bytes([nuevo]))
    except: pass

def ejecutar_ciclo(piezas):
    """Ejecuta la secuencia completa de estados del robot"""
    EST_M4_ABRIR_1        = 1
    EST_M2_ATRAS_1        = 2
    EST_M2_ADELANTE_55    = 3
    EST_M3_SUBIR_1        = 4
    EST_M1_IZQ_75         = 5
    EST_M3_BAJAR_1        = 6
    EST_M4_CERRAR_1       = 7
    EST_M3_SUBIR_2        = 8
    EST_M1_DER_25         = 9
    EST_M3_BAJAR_2        = 12
    EST_M4_ABRIR_ESPERA   = 13
    EST_M4_CERRAR_2       = 19
    EST_M3_SUBIR_3        = 20
    EST_M1_DER_50         = 21
    EST_M3_BAJAR_3        = 22
    EST_M4_ABRIR_FINAL    = 23
    EST_FIN_DEFINITIVO    = 24

    for p in range(piezas):
        print(f"--- Robot: Iniciando Pieza {p+1}/{piezas} ---")
        estado = EST_M4_ABRIR_1
        motor_inicializado = False
        contador_pulsos = 0
        ultimo_pulso = 0

        while estado != EST_FIN_DEFINITIVO:
            try:
                # PASO 1: ABRIR PINZA
                if estado == EST_M4_ABRIR_1:
                    if not motor_inicializado:
                        lectura = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                        if (lectura & MASK_S8):
                            estado = EST_M2_ATRAS_1
                            continue
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111101]))
                        motor_inicializado = True
                    if (i2c.readfrom(DIRECCION_ENTRADAS, 1)[0] & MASK_S8):
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M2_ATRAS_1
                        motor_inicializado = False

                # PASO 2: ATRÁS
                elif estado == EST_M2_ATRAS_1:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11101111]))
                        motor_inicializado = True
                    if (i2c.readfrom(DIRECCION_ENTRADAS, 1)[0] & MASK_S4):
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M2_ADELANTE_55
                        motor_inicializado = False

                # PASO 3: ADELANTE (68 PULSOS)
                elif estado == EST_M2_ADELANTE_55:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11011111]))
                        contador_pulsos = 0
                        motor_inicializado = True
                    curr = 1 if (i2c.readfrom(DIRECCION_ENTRADAS, 1)[0] & MASK_S3) else 0
                    if curr == 1 and ultimo_pulso == 0:
                        contador_pulsos += 1
                        print(f"M2: {contador_pulsos}/68")
                    ultimo_pulso = curr
                    if contador_pulsos >= 68:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M3_SUBIR_1
                        motor_inicializado = False

                # PASO 4: SUBIR M3 (SENSOR 119 O TIEMPO)
                elif estado == EST_M3_SUBIR_1:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11110111]))
                        tiempo_inicio = time.ticks_ms()
                        motor_inicializado = True
                    lectura = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if lectura == 119 or time.ticks_diff(time.ticks_ms(), tiempo_inicio) >= 3000:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M1_IZQ_75
                        motor_inicializado = False

                # PASO 5: M1 IZQUIERDA (75 PULSOS)
                elif estado == EST_M1_IZQ_75:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b01111111]))
                        contador_pulsos = 0
                        motor_inicializado = True
                    curr = 1 if (i2c.readfrom(DIRECCION_ENTRADAS, 1)[0] & MASK_S1) else 0
                    if curr == 1 and ultimo_pulso == 0:
                        contador_pulsos += 1
                        print(f"M1-IZQ: {contador_pulsos}/75")
                    ultimo_pulso = curr
                    if contador_pulsos >= 75:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M3_BAJAR_1
                        motor_inicializado = False

                # PASO 6: BAJAR M3 (2.9s)
                elif estado == EST_M3_BAJAR_1:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111011]))
                        tiempo_inicio = time.ticks_ms()
                        motor_inicializado = True
                    if time.ticks_diff(time.ticks_ms(), tiempo_inicio) >= 2900:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M4_CERRAR_1
                        motor_inicializado = False

                # PASO 7: CERRAR PINZA (7 PULSOS)
                elif estado == EST_M4_CERRAR_1:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111110]))
                        contador_pulsos = 0
                        motor_inicializado = True
                    curr = 1 if (i2c.readfrom(DIRECCION_ENTRADAS, 1)[0] & MASK_S7) else 0
                    if curr == 1 and ultimo_pulso == 0: contador_pulsos += 1
                    ultimo_pulso = curr
                    if contador_pulsos >= 9:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M3_SUBIR_2
                        motor_inicializado = False

                # PASO 8: SUBIR M3 COMPLETO
                elif estado == EST_M3_SUBIR_2:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11110111]))
                        tiempo_inicio = time.ticks_ms()
                        motor_inicializado = True
                    lectura = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if lectura == 119 or time.ticks_diff(time.ticks_ms(), tiempo_inicio) >= 3000:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M1_DER_25
                        motor_inicializado = False

                # PASO 9: M1 DERECHA (25 PULSOS)
                elif estado == EST_M1_DER_25:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b10111111]))
                        contador_pulsos = 0
                        motor_inicializado = True
                    curr = 1 if (i2c.readfrom(DIRECCION_ENTRADAS, 1)[0] & MASK_S1) else 0
                    if curr == 1 and ultimo_pulso == 0: contador_pulsos += 1
                    ultimo_pulso = curr
                    if contador_pulsos >= 25:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M3_BAJAR_2
                        motor_inicializado = False

                # PASO 12: BAJAR M3 (2.9s)
                elif estado == EST_M3_BAJAR_2:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111011]))
                        tiempo_inicio = time.ticks_ms()
                        motor_inicializado = True
                    if time.ticks_diff(time.ticks_ms(), tiempo_inicio) >= 2900:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M4_ABRIR_ESPERA
                        motor_inicializado = False

                # PASO 13: ABRIR PINZA (ESPERA MAQUINADO)
                elif estado == EST_M4_ABRIR_ESPERA:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111101]))
                        motor_inicializado = True
                    if (i2c.readfrom(DIRECCION_ENTRADAS, 1)[0] & MASK_S8):
                        apagar_todo()
                        time.sleep(1) # Simulación breve de espera
                        estado = EST_M4_CERRAR_2
                        motor_inicializado = False

                # PASO 19: CERRAR PINZA RETORNO (7 PULSOS)
                elif estado == EST_M4_CERRAR_2:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111110]))
                        contador_pulsos = 0
                        motor_inicializado = True
                    curr = 1 if (i2c.readfrom(DIRECCION_ENTRADAS, 1)[0] & MASK_S7) else 0
                    if curr == 1 and ultimo_pulso == 0: contador_pulsos += 1
                    ultimo_pulso = curr
                    if contador_pulsos >= 9:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M3_SUBIR_3
                        motor_inicializado = False

                # PASO 20: SUBIR M3
                elif estado == EST_M3_SUBIR_3:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11110111]))
                        tiempo_inicio = time.ticks_ms()
                        motor_inicializado = True
                    lectura = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if lectura == 119 or time.ticks_diff(time.ticks_ms(), tiempo_inicio) >= 3000:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M1_DER_50
                        motor_inicializado = False

                # PASO 21: M1 DERECHA FINAL (50 PULSOS)
                elif estado == EST_M1_DER_50:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b10111111]))
                        contador_pulsos = 0
                        motor_inicializado = True
                    curr = 1 if (i2c.readfrom(DIRECCION_ENTRADAS, 1)[0] & MASK_S1) else 0
                    if curr == 1 and ultimo_pulso == 0: contador_pulsos += 1
                    ultimo_pulso = curr
                    if contador_pulsos >= 50:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M3_BAJAR_3
                        motor_inicializado = False

                # PASO 22: BAJAR M3 FINAL
                elif estado == EST_M3_BAJAR_3:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111011]))
                        tiempo_inicio = time.ticks_ms()
                        motor_inicializado = True
                    if time.ticks_diff(time.ticks_ms(), tiempo_inicio) >= 2700:
                        apagar_todo()
                        time.sleep(0.5)
                        estado = EST_M4_ABRIR_FINAL
                        motor_inicializado = False

                # PASO 23: ABRIR PINZA FINAL
                elif estado == EST_M4_ABRIR_FINAL:
                    if not motor_inicializado:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111101]))
                        motor_inicializado = True
                    if (i2c.readfrom(DIRECCION_ENTRADAS, 1)[0] & MASK_S8):
                        apagar_todo()
                        estado = EST_FIN_DEFINITIVO

                time.sleep(0.005)
            except OSError: pass

    print("--- Ciclo de Producción del Robot Finalizado ---")
