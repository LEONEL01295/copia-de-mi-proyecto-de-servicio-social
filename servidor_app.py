import socket
import json
import time

# Variable global para mantener la conexión
conexion_cliente = None

def recibir_mensaje(conn):
    """
    Lee mensajes directos (Socket RAW) de Flutter.
    """
    try:
        # Leemos hasta el salto de línea o un bloque de datos
        datos = conn.recv(1024)
        if not datos:
            return None
        return datos.decode('utf-8').strip()
    except OSError:
        return ""
    except Exception as e:
        print("Error al recibir:", e)
        return None

def enviar_mensaje(conn, mensaje):
    """
    Envía mensaje directo de texto a Flutter.
    """
    try:
        # Agregamos salto de línea para que Flutter sepa que terminó el mensaje
        conn.send((mensaje + "\n").encode('utf-8'))
    except Exception as e:
        print("Error al enviar:", e)

def iniciar_servidor(puerto=8080):
    """
    Inicia servidor TCP RAW (más estable que WebSocket para MicroPython).
    """
    servidor = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    servidor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    servidor.bind(('0.0.0.0', puerto))
    servidor.listen(1)
    servidor.setblocking(False)
    print(f"Servidor RAW activo en puerto {puerto}... [MÁXIMA ESTABILIDAD]")
    return servidor

def atender_conexiones(servidor, procesar_mensaje_callback):
    """
    Gestiona la conexión única sin bloquear el sistema.
    """
    global conexion_cliente

    if conexion_cliente is None:
        try:
            conn, addr = servidor.accept()
            print("¡App vinculada desde:", addr, "!")
            conn.settimeout(0.02) # Tiempo de respuesta rápido
            conexion_cliente = conn
        except OSError:
            pass
    else:
        try:
            mensaje_recibido = recibir_mensaje(conexion_cliente)

            if mensaje_recibido is None:
                raise Exception("Enlace perdido")

            if mensaje_recibido != "":
                # Ignorar latidos
                if '"comando": "ping"' in mensaje_recibido:
                    return

                print("App manda:", mensaje_recibido)
                respuesta = procesar_mensaje_callback(mensaje_recibido)
                if respuesta:
                    enviar_mensaje(conexion_cliente, respuesta)

        except Exception:
            print("Reiniciando canal...")
            try:
                conexion_cliente.close()
            except:
                pass
            conexion_cliente = None
