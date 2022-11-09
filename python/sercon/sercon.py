
import serial
import threading
import signal

# A simple serial console.
# Type a line and press enter
# and it goes to serial port.
# Chars get read on another thread.

ser = serial.Serial("COM5", 57600, timeout=1)

def handler(signum, frame):
    ser.close()
    exit(1)

signal.signal(signal.SIGINT, handler)

def thread_func(name):
    while True:
        try:
            if ser.inWaiting():
                c = ser.read()
                print(chr(c[0]),end="")
            if ser.closed:
                break
        except:
            break

x = threading.Thread(target=thread_func, args=(1,))
x.start()

while True:
    aline = input()
    aline += '\n'
    ser.write(aline.encode())
