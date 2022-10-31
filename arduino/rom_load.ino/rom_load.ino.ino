
#define WRITE_ENABLE 15
#define LATCH_CLOCK 16
#define SHIFT_CLOCK 17
#define SERIAL_DATA 18
#define OUTPUT_ENABLE 19
#define EEPROM_D0 6
#define EEPROM_D7 13

// BEGIN EEPROM Functions
void setAddress(int address, bool outputEnable)
{
  shiftOut(SERIAL_DATA, SHIFT_CLOCK, MSBFIRST, address >> 8);
  shiftOut(SERIAL_DATA, SHIFT_CLOCK, MSBFIRST, address);
  digitalWrite(OUTPUT_ENABLE, outputEnable ? LOW : HIGH);
  digitalWrite(LATCH_CLOCK, LOW);
  digitalWrite(LATCH_CLOCK, HIGH);
  digitalWrite(LATCH_CLOCK, LOW);
}

byte readEEPROM(int address)
{
  for(int pin = EEPROM_D0; pin <= EEPROM_D7; pin++)
  {
    pinMode(pin, INPUT);
  }
  setAddress(address, true);
  byte data = 0;
  for(int pin = EEPROM_D7; pin >= EEPROM_D0; pin -= 1)
  {
    data = (data << 1) + digitalRead(pin);
  }
  return data;
}

void writeEEPROM(int address, byte data)
{
  for(int pin = EEPROM_D0; pin <= EEPROM_D7; pin++)
  {
    pinMode(pin, OUTPUT);
  }
  setAddress(address, false);
  for(int pin = EEPROM_D0; pin <= EEPROM_D7; pin++)
  {
    digitalWrite(pin, data & 0x01);
    data = data >> 1;
  }
  digitalWrite(WRITE_ENABLE, LOW);
  delayMicroseconds(1);
  digitalWrite(WRITE_ENABLE, HIGH);
  delay(10);
}

// 256 bytes at a time
void printContents(int address)
{
  for(int base = address; base < address + 256; base += 16)
  {
    byte data[16];
    for(int offset = 0; offset < 16; offset++)
    {
      data[offset] = readEEPROM(base + offset);
    }
    char buf[128];
    sprintf(buf, "%04x: %02x %02x %02x %02x %02x %02x %02x %02x   %02x %02x %02x %02x %02x %02x %02x %02x",
      base, data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7], data[8],
      data[9], data[10], data[11], data[12], data[13], data[14], data[15]);
    Serial.println(buf);
  }  
}
// END EEPROM Functions

void setup() {
  Serial.begin(57600);

  // pin setup
  // EEPROM pins will be set right before read or write
  digitalWrite(WRITE_ENABLE, HIGH);
  pinMode(WRITE_ENABLE, OUTPUT);
  pinMode(LATCH_CLOCK, OUTPUT);
  pinMode(SHIFT_CLOCK, OUTPUT);
  pinMode(SERIAL_DATA, OUTPUT);
  pinMode(OUTPUT_ENABLE, OUTPUT);

  Serial.println();
}

int state = 0;    // parse state
int instr = 0;    // instruction
int addrlo = 0;   // addr lo
int addrhi = 0;   // addr hi
int btf = 0;      // byte to follow
int btfctr = 0;   // counter used in reading bytes to follow
byte buffer[59];  // buffer of bytes to follow
int timeout = 0;  // timeout counter

void instr1()
{
  // write data to ROM
  // we're going to load the rom here
  // bit bang a pin to load the address onto two chained
  // 74HC595 8-bit serial shift register output latches
  // to make a 16-bit address for the ROM
  // then, load an 8-bit value into the MCP23008 IO Expander
  // using I2C or SPI
  // then, send a clock pulse to the ROM to load the value

  // then, send a result back via serial      
  Serial.print("Received ");
  Serial.print(btf);
  Serial.print(" bytes to write to address 0x");
  Serial.print(addrhi, HEX);
  Serial.print(addrlo, HEX);
  Serial.println();
  //Serial.print(" data: ");
  //for(int i=0; i<btf; i++)
  //{
    //Serial.print(buffer[i], HEX);
    //Serial.print(" ");
  //}

  // write the data to the ROM
  Serial.println("Writing contents to ROM...");
  int addr_to_write = (addrhi << 8) + addrlo;
  for(int offset = 0; offset < btf; offset++)
  {
    writeEEPROM(addr_to_write + offset, buffer[offset]);
  }

  Serial.println("Done.");
}

void instr2()
{
  // read 256 bytes of data from ROM at addr
  int addr_to_read = (addrhi << 8) + addrlo;
  printContents(addr_to_read);  
}

// serial read buffer holds 64 bytes
void loop() {

  // check if data is available
  if (Serial.available() > 0) {
    
    // read the incoming byte:
    byte byte_in = Serial.read();

    if(0 == state && byte_in == 0xfe)
    {
      // zero state and magic number received
      // start of a packet of data
      state = 1;
      timeout = 0;
    }
    else if(state == 1)
    {
      // store the instruction
      instr = byte_in;
      state = 2;
    }
    else if(state == 2)
    {
      // store the addr lo byte
      addrlo = byte_in;
      state = 3;
    }
    else if(state == 3)
    {
      // store the addr hi byte
      addrhi = byte_in;
      state = 4;
    }
    else if(state == 4) 
    {
      // store the number of bytes to follow (btf)
      btf = byte_in;
      btfctr = btf;
      if(btf > -1 && btf < 60) {
        state = 5;
        // if no bytes to read, go straight to state 6
        // execute instruction
        if(btf == 0) state = 6;
      }
      else 
      {
        // if btf is out of range, just reset state
        btf = 0;
        btfctr = 0;
        state = 0;
      }      
    }
    else if(state == 5)
    {
      // read bytes until btfctr is zero
      if(btfctr > 0)
      {
        buffer[btf - btfctr] = byte_in;
        btfctr--;
        // if done reading, go to state 6 (exec instr)
        if(btfctr == 0) state = 6;
      }
    }
  }
  else if(state == 6 && btfctr == 0)
  {
    // if no data available and state = 6 (ready to execute instruction)
    // and all the buffer data has been read
    switch(instr)
    {
      case 0x01:
        instr1();
      break;
      case 0x02:
        instr2();
      break;
    }
    Serial.write(0xff);
    state = 0;
  }
  else 
  {
    // no data to read
    // keep trying for 16 million cycles
    // then reset state to zero
    timeout++;
    if(timeout > 16000000) {
      timeout = 0;
      state = 0;
    }
  }
}
