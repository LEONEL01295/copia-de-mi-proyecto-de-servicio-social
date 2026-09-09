from machine import Pin, I2C
import time
import json
import servidor_app
import robot
import prensado

# Inicializar I2C
i2c = I2C(0, scl=Pin(5), sda=Pin(4))

# Global para sincronización paralela
sync_signal = None
modo_actual = "placa1" # Controla si espera o no a P2

# -------------------------------------------------------------------------
# MÁSCARAS Y ESTADOS (Plate 1)
# -------------------------------------------------------------------------
MASK_S1, MASK_S3, MASK_S4, MASK_S7, MASK_S8 = 0b10, 0b100, 0b1000, 0b1000000, 0b10000000
MASCARA_ORIGEN = 0b00000100
btm_est1, btm_est2, btm_est3, btm_est4 = 0b11, 0b01, 0b1011, 0b111

def apagar_emergencia():
    try:
        i2c.writeto(0x24, bytes([0b11111111]))
        i2c.writeto(0x25, bytes([0b11111111]))
    except: pass

def ejecutar_ciclo_unificado_p1(piezas):
    global sync_signal, modo_actual
    print(f"--- INICIANDO P1 (Modo: {modo_actual}) ---")

    for p in range(piezas):
        estado = 1
        motor_inicializado = False
        contador_pulsos = ultimo_pulso = 0

        while estado != 24:
            try:
                # --- PASOS 1 AL 5 (Robot inicial) ---
                if estado == 1:
                    if not motor_inicializado:
                        if (i2c.readfrom(0x21, 1)[0] & MASK_S8) != 0: estado = 2; continue
                        i2c.writeto(0x24, bytes([0b11111101])); motor_inicializado = True
                    if (i2c.readfrom(0x21, 1)[0] & MASK_S8) != 0:
                        i2c.writeto(0x24, bytes([0b11111111])); time.sleep(0.5); estado = 2; motor_inicializado = False

                elif estado == 2:
                    if not motor_inicializado: i2c.writeto(0x24, bytes([0b11101111])); motor_inicializado = True
                    if (i2c.readfrom(0x21, 1)[0] & MASK_S4) != 0:
                        i2c.writeto(0x24, bytes([0b11111111])); time.sleep(0.5); estado = 3; motor_inicializado = False

                elif estado == 3:
                    if not motor_inicializado: i2c.writeto(0x24, bytes([0b11011111])); motor_inicializado = True
                    pulso = 1 if (i2c.readfrom(0x21, 1)[0] & MASK_S3) else 0
                    if pulso == 1 and ultimo_pulso == 0: contador_pulsos += 1
                    ultimo_pulso = pulso
                    if contador_pulsos >= 68: i2c.writeto(0x24, bytes([0b11111111])); time.sleep(0.5); estado = 4; motor_inicializado = False

                elif estado == 4:
                    if not motor_inicializado: i2c.writeto(0x24, bytes([0b11110111])); motor_inicializado = True
                    if i2c.readfrom(0x21, 1)[0] == 119: i2c.writeto(0x24, bytes([0b11111111])); time.sleep(0.5); estado = 5; motor_inicializado = False

                elif estado == 5:
                    if not motor_inicializado: i2c.writeto(0x24, bytes([0b01111111])); contador_pulsos = 0; motor_inicializado = True
                    pulso = 1 if (i2c.readfrom(0x21, 1)[0] & MASK_S1) else 0
                    if pulso == 1 and ultimo_pulso == 0: contador_pulsos += 1
                    ultimo_pulso = pulso
                    if contador_pulsos >= 75: i2c.writeto(0x24, bytes([0b11111111])); time.sleep(0.5); estado = 6; motor_inicializado = False

                # =============================================================
                # PASO 6: SINCRONIZACIÓN PARALELA (BAJAR BRAZO)
                # =============================================================
                elif estado == 6:
                    if modo_actual == "general":
                        print("P1: Esperando señal de Maquinados (P2)...")
                        while sync_signal != "bajar_brazo": time.sleep(0.1)

                    print("P1: Bajando M3...")
                    i2c.writeto(0x24, bytes([0b11111011]))
                    time.sleep(2.9)
                    i2c.writeto(0x24, bytes([0b11111111]))

                    if modo_actual == "general":
                        print("P1: Brazo abajo. Esperando que termine Maquinado...")
                        while sync_signal != "continuar_robot": time.sleep(0.1)

                    sync_signal = None
                    estado = 7

                # --- PASOS 7 AL 24 (Robot final + Prensa) ---
                elif estado == 7: # Cerrar
                    if not motor_inicializado: i2c.writeto(0x24, bytes([0b11111110])); contador_pulsos = 0; motor_inicializado = True
                    pulso = 1 if (i2c.readfrom(0x21, 1)[0] & MASK_S7) else 0
                    if pulso == 1 and ultimo_pulso == 0: contador_pulsos += 1
                    ultimo_pulso = pulso
                    if contador_pulsos >= 9: i2c.writeto(0x24, bytes([0b11111111])); time.sleep(0.5); estado = 8; motor_inicializado = False

                # ... Lógica de Prensa Integrada ...
                elif estado == 13: # Robot entrega
                    i2c.writeto(0x24, bytes([0b11111101])); time.sleep(1); i2c.writeto(0x24, bytes([0b11111111])); estado = 14

                elif estado == 14: # Prensa
                    if (i2c.readfrom(0x22, 1)[0] & MASCARA_ORIGEN) == 4: estado = 15
                    else: i2c.writeto(0x25, bytes([0b10111111]))

                elif estado == 15: i2c.writeto(0x25, bytes([0b11011111])); time.sleep(5); estado = 16
                elif estado == 16:
                    if (i2c.readfrom(0x22, 1)[0] & btm_est2) == 1: i2c.writeto(0x25, bytes([0b01111111])); estado = 17
                elif estado == 17:
                    if (i2c.readfrom(0x22, 1)[0] & btm_est3) == 11: i2c.writeto(0x25, bytes([0b10111111])); estado = 18
                elif estado == 18:
                    if (i2c.readfrom(0x22, 1)[0] & btm_est4) == 7: i2c.writeto(0x25, bytes([0b11101111])); time.sleep(5); i2c.writeto(0x25, bytes([0b11111111])); estado = 24

                time.sleep(0.005)
            except OSError: pass

def procesar_orden(mensaje):
    global sync_signal, modo_actual
    try:
        data = json.loads(mensaje)
        cmd = data.get("comando")

        if cmd == "sync_robot":
            sync_signal = data.get("msg")
            return json.dumps({"status": "ok"})

        if cmd == "start":
            modo_actual = data.get("maqueta") # "placa1" o "general"
            ejecutar_ciclo_unificado_p1(data.get("piezas", 1))
            return json.dumps({"status": "ok"})

        elif cmd == "manual_control":
            rele, val = data.get("rele"), data.get("valor")
            if data.get("maqueta") == "robot": robot.controlar_actuador(rele, val)
            else: prensado.controlar_actuador(rele, val)
            return json.dumps({"status": "ok"})

        elif cmd == "emergency_stop" or cmd == "reset":
            apagar_emergencia(); return json.dumps({"status": "ready"})
    except: return None

servidor = servidor_app.iniciar_servidor()
while True:
    servidor_app.atender_conexiones(servidor, procesar_orden)
    time.sleep(0.002)
