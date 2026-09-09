from machine import Pin, I2C
import time

# I2C compartido
i2c = I2C(0, scl=Pin(5), sda=Pin(4))

# Direcciones I2C (Placa 2)
DIRECCION_ENTRADAS = 0x22
DIRECCION_RELES    = 0x25

# Máscaras Sensores Neumático (Originales)
btm_est1  = 0b00000101
btm_est2  = 0b00001110
btm_est3  = 0b00001100
btm_est4  = 0b00100100

def apagar_todo():
    """Apaga actuadores de neumático"""
    try: i2c.writeto(DIRECCION_RELES, bytes([0b11111111]))
    except: pass

def controlar_actuador(rele_index, encender):
    """Control manual para Neumático"""
    try:
        actual = i2c.readfrom(DIRECCION_RELES, 1)[0]
        nuevo = (actual & ~(1 << rele_index)) if encender else (actual | (1 << rele_index))
        i2c.writeto(DIRECCION_RELES, bytes([nuevo]))
    except: pass

def ejecutar_ciclo(piezas):
    """Secuencia ORIGINAL de Neumático con Alineación Inicial"""
    print(f"--- INICIANDO NEUMÁTICO: {piezas} piezas ---")

    for p in range(piezas):
        print(f"Procesando pieza {p+1} de {piezas}")

        # FASE 0: Alineación de plataforma (Variable 'a' en lógica original)
        alineado = False
        print("Alineando plataforma...")
        while not alineado:
            try:
                in0 = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                if in0 == 173:
                    print("Plataforma detectada en posición.")
                    apagar_todo()
                    time.sleep(1)
                    alineado = True
                else:
                    # Moviendo plataforma para alinear
                    i2c.writeto(DIRECCION_RELES, bytes([0b10111111]))
                time.sleep(0.1)
            except OSError: time.sleep(0.5)

        # INICIO DE SECUENCIA DE ESTADOS (1 al 4)
        estado = 1
        while estado <= 4:
            try:
                # ESTADO 1: Esperando paquete y Compresor
                if estado == 1:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if (in0 & btm_est1) == 4:
                        print("Paso 1: Encendiendo compresor")
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111110]))
                        time.sleep(3)
                        print("Apagando compresor")
                        apagar_todo(); time.sleep(1)
                        print("Paso 3: Pistón empuje (Sale)")
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111101]))
                        time.sleep(1)
                        print("Paso 4: Pistón empuje (Retrae)")
                        i2c.writeto(DIRECCION_RELES, bytes([0b11111011]))
                        time.sleep(1)
                        print("Paso 5: Girando plataforma")
                        i2c.writeto(DIRECCION_RELES, bytes([0b10111111]))
                        time.sleep(1)
                        estado = 2

                # ESTADO 2: Sensor de empaque
                elif estado == 2:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if (in0 & btm_est2) == 6:
                        print("Paso 1: Apagando plataforma")
                        apagar_todo(); time.sleep(1)
                        print("Paso 2: Pistón empaquetar (Sale)")
                        i2c.writeto(DIRECCION_RELES, bytes([0b11110111]))
                        time.sleep(1)
                        print("Paso 3: Pistón empaquetar (Retrae)")
                        apagar_todo(); time.sleep(1)
                        print("Giro + Compresor")
                        i2c.writeto(DIRECCION_RELES, bytes([0b10111110]))
                        time.sleep(3)
                        estado = 3

                # ESTADO 3: Posición correcta y expulsión
                elif estado == 3:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if (in0 & btm_est3) == 12:
                        print("Paso 1: Apagando todo")
                        apagar_todo(); time.sleep(1)
                        print("Paso 2: Expulsando paquete")
                        i2c.writeto(DIRECCION_RELES, bytes([0b11101111]))
                        time.sleep(1)
                        print("Paso 3: Retrayendo expulsión")
                        i2c.writeto(DIRECCION_RELES, bytes([0b11011111]))
                        time.sleep(1)
                        print("Paso 4: Banda transportadora ON")
                        i2c.writeto(DIRECCION_RELES, bytes([0b01111111]))
                        estado = 4

                # ESTADO 4: Final de cinta
                elif estado == 4:
                    in0 = i2c.readfrom(DIRECCION_ENTRADAS, 1)[0]
                    if (in0 & btm_est4) == 4:
                        print("Pieza lista en final.")
                        apagar_todo(); time.sleep(2)
                        estado = 5 # Termina bucle de pieza

                time.sleep(0.1)
            except OSError: pass

    print("--- CICLO NEUMÁTICO FINALIZADO ---")
