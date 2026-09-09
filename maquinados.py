from machine import Pin, I2C
import time

# I2C compartido
i2c = I2C(0, scl=Pin(5), sda=Pin(4))

# Direcciones I2C (Placa 2)
DIRECCION_ENTRADAS_P2 = 0x22
DIRECCION_ENTRADAS_P1 = 0x21 # Sensores imanes
DIRECCION_RELES       = 0x24

# Máscaras Maquinados (Originales)
btm_est5  = 0b10000100
btm_est6  = 0b00000001
btm_est7  = 0b00000010
btm_est8  = 0b00000100
btm_est9  = 0b00010000
btm_est10 = 0b00100000

def apagar_todo():
    """Apaga actuadores de maquinados"""
    try: i2c.writeto(DIRECCION_RELES, bytes([0b11111111]))
    except: pass

def controlar_actuador(rele_index, encender):
    """Control manual para Maquinados"""
    try:
        actual = i2c.readfrom(DIRECCION_RELES, 1)[0]
        nuevo = (actual & ~(1 << rele_index)) if encender else (actual | (1 << rele_index))
        i2c.writeto(DIRECCION_RELES, bytes([nuevo]))
    except: pass

def ejecutar_ciclo(piezas):
    """Secuencia ORIGINAL de Maquinados adaptada para múltiples piezas"""
    print(f"--- INICIANDO MAQUETA DE MAQUINADOS: {piezas} piezas ---")

    for p in range(piezas):
        print(f"Procesando pieza {p+1} de {piezas}")
        estado = 5

        # Apagado inicial de seguridad por pieza
        apagar_todo()

        # Bucle de la secuencia original (est5 a est10)
        while estado <= 10:
            try:
                # ESTADO 5: Esperando entrada
                if estado == 5:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS_P2, 1)[0]
                    entr5 = in0 & btm_est5
                    if entr5 == 4:
                        time.sleep(2)
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111101]))
                        # Lectura en falso para preparar el siguiente paso
                        i2c.readfrom(DIRECCION_ENTRADAS_P1, 1)[0]
                        estado = 6

                # ESTADO 6: Imán 1
                elif estado == 6:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS_P1, 1)[0]
                    entr6 = in0 & btm_est6
                    time.sleep(0.5)
                    if entr6 == 0:
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111011]))
                        estado = 7

                # ESTADO 7: Primer Tornillo
                elif estado == 7:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS_P1, 1)[0]
                    entr7 = in0 & btm_est7
                    if entr7 == 0:
                        # Encendiendo tornillo 1
                        i2c.writeto(DIRECCION_RELES, bytes([0b11110111]))
                        time.sleep(1)
                        # Encendiendo segunda banda
                        i2c.writeto(DIRECCION_RELES, bytes([0b11101011]))
                        time.sleep(1)
                        # Activando combinación de salida
                        i2c.writeto(DIRECCION_RELES, bytes([0b11101011]))
                        time.sleep(0.5)
                        i2c.writeto(DIRECCION_RELES, bytes([0b11101111]))
                        time.sleep(0.5)
                        estado = 8

                # ESTADO 8: Segundo Tornillo por tiempo
                elif estado == 8:
                    # Lectura de sensor (se ignora según lógica original)
                    i2c.readfrom(DIRECCION_ENTRADAS_P1, 1)[0]
                    i2c.writeto(DIRECCION_RELES, bytes([0b11011111]))
                    time.sleep(1)
                    i2c.writeto(DIRECCION_RELES, bytes([0b11101111]))
                    time.sleep(3)

                    # Apagado temporal
                    i2c.writeto(DIRECCION_RELES, bytes([0b11111111]))
                    time.sleep(2)
                    i2c.writeto(DIRECCION_RELES, bytes([0b10111111]))
                    estado = 9

                # ESTADO 9: Sensor Est10
                elif estado == 9:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS_P1, 1)[0]
                    entr9 = in0 & btm_est9
                    time.sleep(0.5)
                    if entr9 == 0:
                         i2c.writeto(DIRECCION_RELES, bytes([0b01111111]))
                         estado = 10

                # ESTADO 10: Último Tornillo / Reinicio
                elif estado == 10:
                    i2c.readfrom(DIRECCION_ENTRADAS_P1, 1)[0]
                    time.sleep(5)
                    apagar_todo()
                    print(f"Pieza {p+1} terminada.")
                    estado = 11 # Sale del while para ir a la siguiente pieza

                time.sleep(0.1)
            except OSError:
                time.sleep(0.5)
                pass

    print("--- CICLO DE MAQUINADOS FINALIZADO ---")
