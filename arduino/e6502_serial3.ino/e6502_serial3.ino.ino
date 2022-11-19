
// wa 48, now 15
#define RS_A0 15  // 0=instr; 1=data

// was 21, now 3
#define CE_A1 3   // 0=disable; 1=enable (needs interrupt pin)

// was 52, now 16
#define RW_A2 16  // 0=read; 1=write (from Arduino perspective)

// was 46, now 17
#define IRQB  17

// was 44, now 18
#define OUTR1 18  // out register 1

// int PBX[8] = {39,41,43,45,47,49,51,53};
int PBX[8] = {5,6,7,8,9,10,11,12};



void setPortBInput()
{
  pinMode(PBX[0], INPUT);
  pinMode(PBX[1], INPUT);
  pinMode(PBX[2], INPUT);
  pinMode(PBX[3], INPUT);
  pinMode(PBX[4], INPUT);
  pinMode(PBX[5], INPUT);
  pinMode(PBX[6], INPUT);
  pinMode(PBX[7], INPUT);
}

void setPortBOutput()
{
  pinMode(PBX[0], OUTPUT);
  pinMode(PBX[1], OUTPUT);
  pinMode(PBX[2], OUTPUT);
  pinMode(PBX[3], OUTPUT);
  pinMode(PBX[4], OUTPUT);
  pinMode(PBX[5], OUTPUT);
  pinMode(PBX[6], OUTPUT);
  pinMode(PBX[7], OUTPUT);
}

void debugAllLines()
{
  Serial.println("========================================");
  Serial.print("DEBUG: RS_A0 is ");
  Serial.println(digitalRead(RS_A0) ? "HIGH" : "LOW");
  Serial.print("DEBUG: CE_A1 is ");
  Serial.println(digitalRead(CE_A1) ? "HIGH" : "LOW");
  Serial.print("DEBUG: RW_A2 is ");
  Serial.println(digitalRead(RW_A2) ? "HIGH" : "LOW");
  Serial.print("DEBUG: IRQB is ");
  Serial.println(digitalRead(IRQB) ? "HIGH" : "LOW");
  Serial.print("DEBUG: OUTR1 is ");
  Serial.println(digitalRead(OUTR1) ? "HIGH" : "LOW");

  for(int i=0; i<8; i++)
  {
    Serial.print("DEBUG: Data line ");
    Serial.print(i);
    Serial.print(" is ");
    Serial.println(digitalRead(PBX[i]) ? "HIGH" : "LOW");
  }  
  Serial.println("========================================");
}

byte readDataFromPins()
{
  setPortBInput();
  byte result = digitalRead(PBX[0]);
  result += digitalRead(PBX[1]) << 1;
  result += digitalRead(PBX[2]) << 2;
  result += digitalRead(PBX[3]) << 3;
  result += digitalRead(PBX[4]) << 4;
  result += digitalRead(PBX[5]) << 5;
  result += digitalRead(PBX[6]) << 6;
  result += digitalRead(PBX[7]) << 7;
  return result;
}

void writeDataToPins(byte b)
{
  setPortBOutput();
  digitalWrite(PBX[0], b & 0x01);
  digitalWrite(PBX[1], b & 0x02);
  digitalWrite(PBX[2], b & 0x04);
  digitalWrite(PBX[3], b & 0x08);
  digitalWrite(PBX[4], b & 0x10);
  digitalWrite(PBX[5], b & 0x20);
  digitalWrite(PBX[6], b & 0x40);
  digitalWrite(PBX[7], b & 0x80);
}

void setup() {

  Serial.begin(57600);
  Serial.println();
  Serial.println("e6502 serial v2.0");

  digitalWrite(IRQB, HIGH);
  digitalWrite(RS_A0, LOW);
  digitalWrite(CE_A1, LOW);
  digitalWrite(RW_A2, LOW);
  digitalWrite(OUTR1, LOW);

  pinMode(IRQB, OUTPUT);
  pinMode(RS_A0, INPUT);
  pinMode(CE_A1, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(CE_A1), on_ce, FALLING);
  pinMode(RW_A2, INPUT);
  pinMode(OUTR1, OUTPUT);

  setPortBInput();

  debugAllLines();
}

void triggerIRQB()
{
  digitalWrite(IRQB, LOW);
  digitalWrite(IRQB, HIGH);  
}

int action = 0;
int g_rs = 0;
int g_rw = 0;

void on_ce()
{
  if(action == 0)
  {
    g_rs = digitalRead(RS_A0);
    g_rw = digitalRead(RW_A2);
    action = 1;  
  } else {
    //Serial.print("!");
    //Serial.print(g_rs);
    //Serial.println(g_rw);
  }
}

void writeByte(byte outByte, bool hasMore)
{
  digitalWrite(OUTR1, hasMore ? HIGH : LOW);
  writeDataToPins(outByte & 0xff);
  triggerIRQB();  
}

void writeByteIfAvailable()
{   
    if(Serial.available() > 0)
    {
      int outByte = Serial.read();
      writeByte(outByte, true);
    } else { 
      writeByte(0x00, false);
    }
}

void loop() 
{
  if(action == 1)
  {
    if(g_rs)
    {
      // data
      if(g_rw) {
        // Arduino write
        writeByteIfAvailable();
        action = 0;
      } else {
        // Arduino read
        byte inByte = readDataFromPins();
        Serial.print((char)inByte);
        //Serial.println(inByte,HEX);
        action = 0;
        triggerIRQB();
      }
    }
    else
    {
      // instr
      if(g_rw) {
        // Arduino write
        writeByteIfAvailable();
        action = 0;
      } else {
        // Arduino read
        byte inByte = readDataFromPins();
        Serial.print((char)inByte);
        //Serial.println(inByte,HEX);
        action = 0;
        triggerIRQB();
      }
    }
  }
}
