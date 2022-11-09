
import serial
import time

file = open("..\\..\\asm\\mem32k.bin","rb")
membytes = file.read(32768)
file.close()

def writeblock(addr):

    addressHi = address >> 8
    addressLo = address & 0xff

    x = bytearray(3)
    x[0] = addressLo
    x[1] = addressHi
    x[2] = 0x00
    ser.write(x)

    while True:
        msg = ser.readline()
        if len(msg) > 0:
            #print(msg.decode())
            if msg.decode().startswith("ok"):
                break

    x = bytearray(64)
    for i in range(64):
        x[i] = membytes[addr + i]
    ser.write(x)

    while True:
        msg = ser.readline()
        if len(msg) > 0:
            #print(msg.decode())
            if msg.decode().startswith("ok"):
                break

# read file
# write 64 byte blocks

ser = serial.Serial("COM4", 57600, timeout=1)

while True:
    msg = ser.readline()
    if len(msg) > 0:
        #print(msg.decode())
        if msg.decode().startswith("ready"):
            print("Arduino ready...")
            break

address = 0x0

#writeblock(address)

start = time.time()

while address < 0x8000:
    if address % 0x1000 == 0:
        print(f'Writing address ${address:02x}')
    writeblock(address)
    address += 64

end = time.time()
print(f"elapsed {end - start} s")

print("Complete")