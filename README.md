# e6502

This is my own version of the Ben Eater 6502-on-a-breadboard computer.

The computer can commuinicate with a PC via the 6522 and an Arduino Mega through the Aruino's USB serial port.

The heart of it is the 6502 assembly "monitor" or "operating system" (whatever you want to call it). It supports some basic commands sent via serial.

d####    - dumps a single byte of memory

d####:   - dumps 16 bytes of memory (address truncated to 16 byte boundary)

d####::  - dumps 256 bytes of memory (address truncated to 16 byte boundary)

There's a ROM loader that uses an Arduino UNO R3, based off of Ben Eater's ROM loader. The Arduino code is a bit different than Ben's. It works in conjunction with a dotnet rom loader program (not included here) that I may convert to Python.

Thanks to:

[Ben Eater](https://eater.net/)

[Arduino](https://www.arduino.cc/)

[Ben Eater YouTube](https://www.youtube.com/c/BenEater)

https://6502disassembly.com/

http://6502.org/

https://www.asciitable.com/

https://coronax.wordpress.com/2013/07/03/retrochallenge-6522-parallel-communications/
