
import serial
import sys

ser = serial.Serial("COM4", 57600, timeout=1)

while True:
    msg = ser.readline()
    if len(msg) > 0:
        #print(msg.decode())
        if msg.decode().startswith("ready"):
            print("Arduino ready...")
            break

addr = sys.argv[1]
address = int(addr, 16)
addressHi = address >> 8
addressLo = address & 0xff

x = bytearray(3)
x[0] = addressLo
x[1] = addressHi
x[2] = 0x01
ser.write(x)

while True:
    msg = ser.readline()
    if len(msg) > 0:
        if msg.decode().startswith("ok"):
            break

while True:
    msg = ser.readline()
    if len(msg) > 0:
        if msg.decode().startswith("ok"):
            break
        else:
            print(msg.decode().strip())

