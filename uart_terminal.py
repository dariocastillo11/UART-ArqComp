#!/usr/bin/env python3
"""Terminal UART para probar la ALU de la Basys 3."""

from __future__ import annotations

import argparse
import glob
import os
import select
import sys
import termios


DEFAULT_BAUD = 19200
DEFAULT_DEVICE_PATTERN = "usb-Digilent_Digilent_USB_Device_*"


def find_port(explicit_port: str | None) -> str:
    if explicit_port:
        return explicit_port

    by_id = sorted(
        glob.glob(f"/dev/serial/by-id/{DEFAULT_DEVICE_PATTERN}-if01-port0")
    )
    if by_id:
        return by_id[0]

    usb_ports = sorted(glob.glob("/dev/ttyUSB*"))
    if len(usb_ports) == 1:
        return usb_ports[0]

    raise RuntimeError(
        "No se detectó automáticamente la Basys 3. "
        "Usá --port /dev/ttyUSB2."
    )


def configure_port(fd: int) -> list[int]:
    previous = termios.tcgetattr(fd)
    settings = termios.tcgetattr(fd)
    settings[0] = 0
    settings[1] = 0
    settings[2] = (
        termios.B19200
        | termios.CS8
        | termios.CLOCAL
        | termios.CREAD
    )
    settings[3] = 0
    settings[4] = termios.B19200
    settings[5] = termios.B19200
    settings[6][termios.VMIN] = 0
    settings[6][termios.VTIME] = 5
    termios.tcsetattr(fd, termios.TCSANOW, settings)
    return previous


def read_byte(fd: int, timeout: float) -> int:
    ready, _, _ = select.select([fd], [], [], timeout)
    if not ready:
        raise TimeoutError("No llegó respuesta de la FPGA dentro del tiempo esperado.")

    data = os.read(fd, 1)
    if len(data) != 1:
        raise RuntimeError("El puerto devolvió una respuesta vacía.")
    return data[0]


def send_operation(port: str, a: int, b: int, opcode: int, timeout: float) -> int:
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY)
    previous = configure_port(fd)
    try:
        termios.tcflush(fd, termios.TCIOFLUSH)
        payload = bytes((a, b, opcode))
        os.write(fd, payload)
        response = read_byte(fd, timeout)
        print(
            f"Puerto: {port}\n"
            f"Enviado: {a:02X} {b:02X} {opcode:02X}\n"
            f"Recibido: {response:02X} ({response})"
        )
        return response
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, previous)
        os.close(fd)


def parse_byte(value: str, name: str) -> int:
    try:
        parsed = int(value, 0)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            f"{name} debe ser decimal o hexadecimal, por ejemplo 5 o 0x05."
        ) from exc
    if not 0 <= parsed <= 0xFF:
        raise argparse.ArgumentTypeError(f"{name} debe estar entre 0x00 y 0xFF.")
    return parsed


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Envía una operación UART a la ALU de la Basys 3."
    )
    parser.add_argument("--port", help="Puerto serial, por ejemplo /dev/ttyUSB2.")
    parser.add_argument("--a", type=lambda value: parse_byte(value, "A"))
    parser.add_argument("--b", type=lambda value: parse_byte(value, "B"))
    parser.add_argument(
        "--opcode",
        type=lambda value: parse_byte(value, "opcode"),
        help="Código de operación, por ejemplo 0x20 para ADD.",
    )
    parser.add_argument("--timeout", type=float, default=2.0)
    args = parser.parse_args()

    try:
        port = find_port(args.port)
        a = args.a if args.a is not None else parse_byte(
            input("A (ej. 5 o 0x05): "), "A"
        )
        b = args.b if args.b is not None else parse_byte(
            input("B (ej. 3 o 0x03): "), "B"
        )
        opcode = args.opcode if args.opcode is not None else parse_byte(
            input("Opcode (ej. 0x20): "), "opcode"
        )
        send_operation(port, a, b, opcode, args.timeout)
    except (OSError, RuntimeError, TimeoutError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
