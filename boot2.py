import network
import time
import machine
from machine import Pin

# --- CONFIGURACIÓN LED VISUAL (Placa 2) ---
led = Pin(2, Pin.OUT)

# --- PLACA 2: ESCLAVO / ESTACIÓN ---

# 1. PAUSA DE CORTESÍA PARA ARRANQUE SIMULTÁNEO
print("\nEsperando 15s a que Placa 1 esté lista...")
time.sleep(15)

sta = network.WLAN(network.STA_IF)
sta.active(True)

print("==============================================")
print(" PLACA 2: VINCULANDO A LA RED MAESTRA...")

# 2. INTENTO DE CONEXIÓN CON PARPADEO
while not sta.isconnected():
    print("Buscando 'KinCony-Maquetas'...")
    sta.connect('KinCony-Maquetas', 'password123')

    # Parpadea mientras espera el enlace de esta vuelta
    for i in range(10):
        if sta.isconnected(): break
        led.value(not led.value()) # Cambia estado del LED
        time.sleep(0.5)
        print(f"[{10-i}]", end="")

    if not sta.isconnected():
        print("\n[!] No hallada. Reintentando...")
        time.sleep(2)

# 3. FORZAR IP FIJA DEFINITIVA (.10 para evitar conflicto con Tablet)
# Cambiamos a .10 porque la Tablet suele tomar la .2 o .3
sta.ifconfig(('192.168.4.10', '255.255.255.0', '192.168.4.1', '8.8.8.8'))

# LED Apagado o Fijo para indicar conexión EXITOSA
led.value(1)

print("\n¡VINCULACIÓN EXITOSA!")
print(" IP FIJA ASIGNADA PLACA 2: 192.168.4.10")
print("==============================================\n")
