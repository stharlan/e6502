
#define RS_A0 48  // 0=instr; 1=data
#define CE_A1 21  // 0=disable; 1=enable (needs interrupt pin)
#define RW_A2 52  // 0=read; 1=write (from Arduino perspective)
#define IRQB  46
#define OUTR1 44  // out register 1

int PBX[8] = {39,41,43,45,47,49,51,53};

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
  //Serial.println(digitalRead(PBX[0]));
  //Serial.println(digitalRead(PBX[1]));
  //Serial.println(digitalRead(PBX[2]));
  //Serial.println(digitalRead(PBX[3]));
  //Serial.println(digitalRead(PBX[4]));
  //Serial.println(digitalRead(PBX[5]));
  //Serial.println(digitalRead(PBX[6]));
  //Serial.println(digitalRead(PBX[7]));
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

  // default to input
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
    //int outByte = 0xfe;
    //writeByte(outByte, true);
    //Serial.println("DEBUG: Arduino write data...");
    //Serial.print("Out byte = ");
    //Serial.println(outByte, HEX);
    
    if(Serial.available() > 0)
    {
      int outByte = Serial.read();
      writeByte(outByte, true);
      //Serial.println("DEBUG: Arduino write data...");
      //Serial.print("Out byte = ");
      //Serial.println(outByte, HEX);
    } else { 
      writeByte(0x00, false);
      //Serial.println("DEBUG: Arduino write data...");
      //Serial.println("No data for output.");
    }
}

void loop() 
{
  if(action == 1)
  {
    //Serial.println("ACTION!");
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
        triggerIRQB();
        action = 0;
        //Serial.println("DEBUG: Arduino read data...");
        //Serial.print("In byte = ");
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
        triggerIRQB();
        action = 0;
        //Serial.println("DEBUG: Arduino read instr...");
        //Serial.print("In byte = ");
      }
    }
  }
}
