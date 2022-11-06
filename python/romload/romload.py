
import serial

ser = serial.Serial("COM4", 57600, timeout=1)

while True:
    msg = ser.readline()
    if len(msg) > 0:
        print(msg.decode())
        if msg.decode().startswith("ready"):
            break

print("Writing address...")

x = bytearray(2)
x[0] = 0x00
x[1] = 0xff
ser.write(x)

while True:
    msg = ser.readline()
    if len(msg) > 0:
        print(msg.decode())
        if msg.decode().startswith("ok"):
            break

print("Writing bytes...")

x = bytearray(64)
for i in range(64):
    x[i] = i
ser.write(x)

while True:
    msg = ser.readline()
    if len(msg) > 0:
        print(msg.decode())
        if msg.decode().startswith("ok"):
            break
