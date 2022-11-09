
import serial
import threading
import signal
import re
import time

# A simple serial console.
# Type a line and press enter
# and it goes to serial port.
# Chars get read on another thread.

ser = serial.Serial("COM5", 57600, timeout=1)

def local_upload(filen, offset):

    print("-> reading data")
    file = open(filen,"rb")
    membytes = file.read(32768)
    file.close()
    print(f"-> file size {len(membytes)} bytes")
    file_offset = int(offset, 16)

    # write 256 bytes to serial
    # in 64 byte blocks
    for o1 in range(4):
        print(f'-> writing block ${o1}')
        for o2 in range(64):
            # load the byte array from the file data
            bb = membytes[file_offset + (o1 * 64) + o2];
            print(f'-> writing {bb}')
            ser.write(bb);
        # wait a sec...
        time.sleep(0.5)
    print("-> done")

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

p = re.compile("^local upload (.*) ([0-9A-Za-z]{4})$");

while True:
    aline = input()

    # check for local 'upload' command
    m = p.match(aline)
    if m == None:
        aline += '\n'
        ser.write(aline.encode())
    else:
        # load file
        print("-> file = " + m.group(1))
        print("-> ofst = " + m.group(2))
        local_upload(m.group(1), m.group(2))
