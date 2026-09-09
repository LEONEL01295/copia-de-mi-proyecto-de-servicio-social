from machine import Pin, I2C
import time

# I2C compartido
i2c = I2C(0, scl=Pin(5), sda=Pin(4))

# Direcciones I2C (Placa 1)
DIRECCION_ENTRADAS = 0x22
DIRECCION_RELES    = 0x25

# Máscaras Originales
btm_est1 = 0b00000011  # P1 y S1
btm_est2 = 0b00000001  # P2 y S1
btm_est3 = 0b00001011  # P2 y S2
btm_est4 = 0b00000111  # P2 y S1
MASCARA_ORIGEN = 0b00000100

def apagar_todo():
    """Apaga relés de prensa/banda"""
    try: i2c.writeto(DIRECCION_RELES, bytes([0b11111111]))
    except: pass

def controlar_actuador(rele_index, encender):
    """Control manual de relés para Prensado/Banda"""
    try:
        actual = i2c.readfrom(DIRECCION_RELES, 1)[0]
        nuevo = (actual & ~(1 << rele_index)) if encender else (actual | (1 << rele_index))
        i2c.writeto(DIRECCION_RELES, bytes([nuevo]))
    except: pass

def ejecutar_ciclo(piezas):
    """Secuencia ORIGINAL de Prensado (Estados 14 al 24)"""
    print(f"--- PRENSADO: {piezas} piezas ---")

    for p in range(piezas):
        print(f"Procesando pieza {p+1}/{piezas}")
        estado = 14 # EST_PRENSA_ALINEAR
        motor_inicializado = False

        while estado != 24: # EST_FIN_DEFINITIVO
            try:
                # 14: ALINEACIÓN (S1 ARRIBA)
                if estado == 14:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if (in0 & MASCARA_ORIGEN) == 4:
                        print("Prensa alineada.")
                        apagar_todo(); time.sleep(1)
                        estado = 15
                        motor_inicializado = False
                    else:
                        if not motor_inicializado:
                            print("Subiendo prensa...")
                            i2c.writeto(DIRECCION_RELES, bytes([0b10111111])) # Sube
                            motor_inicializado = True
                        time.sleep(0.1)

                # 15: ESTADO 1 (P1 -> BANDA ADELANTE)
                elif estado == 15:
                    print("Esperando pieza en P1...")
                    # Simulación: En hardware real espera el sensor, aquí lanzamos banda
                    i2c.writeto(DIRECCION_RELES, bytes([0b11011111])) # Adelante
                    time.sleep(5)
                    estado = 16

                # 16: ESTADO 2 (P2 -> BAJAR PRENSA)
                elif estado == 16:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if (in0 & btm_est2) == 1:
                        print("P2 detectado. Bajando prensa.")
                        apagar_todo(); time.sleep(0.5)
                        i2c.writeto(DIRECCION_RELES, bytes([0b01111111])) # Baja
                        estado = 17

                # 17: ESTADO 3 (S2 -> SUBIR PRENSA)
                elif estado == 17:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if (in0 & btm_est3) == 11:
                        print("Prensado hecho. Subiendo.")
                        i2c.writeto(DIRECCION_RELES, bytes([0b10111111])) # Sube
                        estado = 18

                # 18: ESTADO 4 (S1 -> REVERSA BANDA)
                elif estado == 18:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if (in0 & btm_est4) == 7:
                        print("Prensa arriba. Reversa banda.")
                        i2c.writeto(DIRECCION_RELES, bytes([0b11101111])) # Reversa
                        time.sleep(5)
                        apagar_todo(); time.sleep(2)
                        estado = 24

                time.sleep(0.005)
            except OSError: pass

    print("--- CICLO PRENSADO FINALIZADO ---")
