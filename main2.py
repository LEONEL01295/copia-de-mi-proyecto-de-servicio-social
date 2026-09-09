from machine import Pin, I2C
import time
import json
import socket
import servidor_app

# Inicializar I2C
i2c = I2C(0, scl=Pin(5), sda=Pin(4))

# Máscaras Originales
btm_est1, btm_est2, btm_est3, btm_est4 = 0b101, 0b1110, 0b1100, 0b100100
btm_est5, btm_est6, btm_est7, btm_est9 = 0b10000100, 0b1, 0b10, 0b10000

def notificar_placa1(mensaje):
    """Envia señal de red a P1 para sincronización paralela"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(1)
        s.connect(('192.168.4.1', 8080))
        s.send(json.dumps({"comando": "sync_robot", "msg": mensaje}).encode() + b'\n')
        s.close()
    except: pass

def apagar_emergencia():
    try:
        i2c.writeto(0x25, bytes([0b11111111]))
        i2c.writeto(0x24, bytes([0b11111111]))
    except: pass

def ejecutar_ciclo_unificado_p2(piezas, sincronizar=False):
    """Ejecuta P2 con opción de disparar sincronización en P1"""
    for p in range(piezas):
        estado = 1
        a = 0
        while estado <= 10:
            try:
                # Fase Alineación
                if a != 23:
                    in0 = i2c.readfrom(0x22, 1)[0]
                    if in0 == 173: a = 23; i2c.writeto(0x25, bytes([0b11111111])); time.sleep(1)
                    else: i2c.writeto(0x25, bytes([0b10111111])); time.sleep(0.1); continue

                # --- LÓGICA NEUMÁTICA ---
                if estado == 1:
                    if (i2c.readfrom(0x22, 1)[0] & btm_est1) == 4:
                        i2c.writeto(0x25, bytes([0b11111110])); time.sleep(3)
                        i2c.writeto(0x25, bytes([0b11111111])); time.sleep(1)
                        i2c.writeto(0x25, bytes([0b11111101])); time.sleep(1)
                        i2c.writeto(0x25, bytes([0b11111011])); time.sleep(1)
                        i2c.writeto(0x25, bytes([0b10111111])); time.sleep(1)
                        estado = 2

                elif estado == 4:
                    if (i2c.readfrom(0x22, 1)[0] & btm_est4) == 4:
                        i2c.writeto(0x24, bytes([0b11111110])); time.sleep(2)
                        estado = 5

                # --- LÓGICA MAQUINADOS + SYNC ---
                elif estado == 5:
                    if (i2c.readfrom(0x22, 1)[0] & btm_est5) == 4:
                        if sincronizar: notificar_placa1("bajar_brazo") # DISPARA ROBOT P1
                        time.sleep(2); i2c.writeto(0x24, bytes([0b11111101])); estado = 6

                elif estado == 6:
                    if (i2c.readfrom(0x21, 1)[0] & btm_est6) == 0:
                        time.sleep(0.5); i2c.writeto(0x24, bytes([0b11111011])); estado = 7

                elif estado == 10:
                    time.sleep(5); apagar_emergencia()
                    if sincronizar: notificar_placa1("continuar_robot") # LIBERA ROBOT P1
                    estado = 11

                time.sleep(0.05)
            except OSError: pass

def procesar_orden(mensaje):
    try:
        data = json.loads(mensaje)
        cmd, maq = data.get("comando"), data.get("maqueta")
        if cmd == "start":
            # Si el comando es 'general' o 'placa2', activamos sincronización
            sincronizar = (maq == "general" or maq == "placa2")
            ejecutar_ciclo_unificado_p2(data.get("piezas", 1), sincronizar)
            return json.dumps({"status": "ok"})
        elif cmd == "emergency_stop": apagar_emergencia(); return json.dumps({"status": "ready"})
    except: return None

servidor = servidor_app.iniciar_servidor()
while True:
    servidor_app.atender_conexiones(servidor, procesar_orden)
    time.sleep(0.002)
