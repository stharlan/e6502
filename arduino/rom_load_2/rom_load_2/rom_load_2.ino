
#define WRITE_ENABLE 15
#define LATCH_CLOCK 16
#define SHIFT_CLOCK 17
#define SERIAL_DATA 18
#define OUTPUT_ENABLE 19
#define EEPROM_D0 6
#define EEPROM_D7 13

byte data_block[64];

// BEGIN EEPROM Functions
void setAddress(int address)
{
  shiftOut(SERIAL_DATA, SHIFT_CLOCK, MSBFIRST, address >> 8);
  shiftOut(SERIAL_DATA, SHIFT_CLOCK, MSBFIRST, address);
  digitalWrite(LATCH_CLOCK, LOW);
  digitalWrite(LATCH_CLOCK, HIGH);
  digitalWrite(LATCH_CLOCK, LOW);
}

void setDataPinsInput()
{
  // set data pins to input
  for(int pin = EEPROM_D0; pin <= EEPROM_D7; pin++)
  {
    pinMode(pin, INPUT);
  }  
}

void setDataPinsOutput()
{
  // set data pins to input
  for(int pin = EEPROM_D0; pin <= EEPROM_D7; pin++)
  {
    digitalWrite(pin, LOW);
    pinMode(pin, OUTPUT);
  }  
}

byte readEEPROM(int address)
{
  // set address on latches
  setAddress(address);

  // enable output
  digitalWrite(OUTPUT_ENABLE, LOW);

  // read pins
  byte data = 0;
  for(int pin = EEPROM_D7; pin >= EEPROM_D0; pin -= 1)
  {
    data = (data << 1) + digitalRead(pin);
  }

  // disable output
  digitalWrite(OUTPUT_ENABLE, HIGH);
  
  return data;
}

void writeEEPROM(int address)
{
  setDataPinsOutput();

  // disable output
  digitalWrite(OUTPUT_ENABLE, HIGH);

  // start high
  digitalWrite(WRITE_ENABLE, HIGH);

  // round off lower 6 bits
  // 64 bytes at a time
  int addr64b = address & 0xffc0;

  for(int offset = 0; offset < 64; offset++)
  {
    // set address
    setAddress(addr64b + offset);

    // set data pins
    byte data = data_block[offset];
    for(int pin = EEPROM_D0; pin <= EEPROM_D7; pin++)
    {
      digitalWrite(pin, data & 0x01);
      data = data >> 1;
    }

    // pulse write enable
    digitalWrite(WRITE_ENABLE, LOW);
    delayMicroseconds(1);
    digitalWrite(WRITE_ENABLE, HIGH);
  }

  // begin data polling
  // write enable high: OK
  // chip enable low: always

  // set all pins to input
  setDataPinsInput();

  // last byte written
  setAddress(addr64b + 63);

  // get bit7 of last byte written
  int bit7 = data_block[63] >> 7;
  int readBit = 99;

  // seems to want a short delay before polling starts
  delay(1);

  // poll until bits are the same
  while(readBit != bit7) {
    digitalWrite(OUTPUT_ENABLE, LOW);
    readBit = digitalRead(EEPROM_D7);
    digitalWrite(OUTPUT_ENABLE, HIGH);
  }
}

// 256 bytes at a time
void printContents(int address)
{
  // 256 byte boundary only
  address = address & 0xff00;

  // enable output
  setDataPinsInput();

  // disable writing
  digitalWrite(WRITE_ENABLE, HIGH);
  
  for(int base = address; base < address + 256; base += 16)
  {
    byte data[16];
    
    // get 16 bytes
    for(int offset = 0; offset < 16; offset++)
    {
      data[offset] = readEEPROM(base + offset);
    }

    // display
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

  // set high - disable
  digitalWrite(WRITE_ENABLE, HIGH);
  pinMode(WRITE_ENABLE, OUTPUT);

  // set high - disable
  digitalWrite(OUTPUT_ENABLE, HIGH);
  pinMode(OUTPUT_ENABLE, OUTPUT);

  digitalWrite(LATCH_CLOCK, LOW);
  pinMode(LATCH_CLOCK, OUTPUT);

  digitalWrite(SHIFT_CLOCK, LOW);
  pinMode(SHIFT_CLOCK, OUTPUT);

  digitalWrite(SERIAL_DATA, LOW);
  pinMode(SERIAL_DATA, OUTPUT);

  // prepare a debug data block
  //for(int i=0; i<64; i++)
  //{
    //data_block[i] = i + 0x0f;
  //}

  //writeEEPROM(0xff00);

  //Serial.println("Ready...");
  //printContents(0xffff);

  Serial.println("ready");
}

// serial read buffer holds 64 bytes
void loop() {
  if(Serial.available() > 0)
  {
    byte address_bytes[2];
    Serial.readBytes(address_bytes, 2);

    // lo byte first $lohi
    int address = address_bytes[0] + (address_bytes[1] << 8);
    
    char buf[16];
    sprintf(buf, "ok %04x", address);
    Serial.println(buf);

    Serial.readBytes(data_block, 64);

    writeEEPROM(address);
    
    Serial.println("ok");    
  }
}
