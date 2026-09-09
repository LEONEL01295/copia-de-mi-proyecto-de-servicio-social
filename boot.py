import network
import webrepl
import time
from machine import Pin

# --- CONFIGURACIÓN LED VISUAL (Placa 1) ---
led = Pin(2, Pin.OUT) # Pin 2 es el LED integrado en la mayoría de ESP32

# --- PLACA 1: MAESTRO / ACCESS POINT ---

ap = network.WLAN(network.AP_IF)
ap.active(True)

# 1. FORZAR IP MAESTRA
ap.ifconfig(('192.168.4.1', '255.255.255.0', '192.168.4.1', '8.8.8.8'))

# 2. CONFIGURAR RED CON LÍMITE DE CLIENTES
ap.config(essid='KinCony-Maquetas', password='password123', authmode=3, max_clients=8)

print("Iniciando Red SCADA...")

# 3. PARPADEO MIENTRAS SE CREA LA RED
while not ap.active():
    led.value(not led.value())
    time.sleep(0.1)

# LED fijo para indicar que la red está LISTA
led.value(1)

print("\n==============================================")
print(" CEREBRO SCADA (PLACA 1) INICIADO ")
print(" SSID : KinCony-Maquetas")
print(" IP   : 192.168.4.1")
print("==============================================\n")

webrepl.start()
