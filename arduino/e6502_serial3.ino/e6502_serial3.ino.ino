
#define CA1 22
#define CA2 24
#define CB1 38
#define CB2 19
#define IRQB 7

int PAX[8] = {37,35,33,31,29,27,25,23};
int PBX[8] = {53,51,49,47,45,43,41,39};

void setup() {

  Serial.begin(57600);
  Serial.println();
  Serial.println("e6502 serial v1.0");

  // put your setup code here, to run once:
  for(int i=0; i<8; i++)
  {
    digitalWrite(PAX[i], LOW);
    pinMode(PAX[i], OUTPUT);
    pinMode(PBX[i], INPUT);
  }

  // interrupt on CB2
  // triggered when data ready
  pinMode(CB2, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(CB2), on_cb2, FALLING);

  // M -> P
  // pulse CB1 on data taken
  digitalWrite(CB1, HIGH);
  pinMode(CB1, OUTPUT);

  // P -> M
  // pulse CA1 on data ready
  digitalWrite(CA1, HIGH);
  pinMode(CA1, OUTPUT);

  pinMode(CA2, INPUT);

  pinMode(IRQB, INPUT);

  Serial.print("CA1 is ");
  Serial.println(digitalRead(CA1) ? "HIGH" : "LOW");
  Serial.print("CA2 is ");
  Serial.println(digitalRead(CA2) ? "HIGH" : "LOW");
  Serial.print("CB1 is ");
  Serial.println(digitalRead(CB1) ? "HIGH" : "LOW");
  Serial.print("CB2 is ");
  Serial.println(digitalRead(CB2) ? "HIGH" : "LOW");
}

// when CB2 goes low, 
// the MP is sending a char
void on_cb2()
{
  // data ready to read
  //Serial.println("CB2 went low, reading pins...");
  int data = 0;
  for(int dp=0; dp<8; dp++)
  {
    // hi bit first
    int v = digitalRead(PBX[dp]);
    //Serial.print(v);
    data = (data << 1) + v;
  }
  //Serial.println();
  //Serial.print("Data ");
  //Serial.println(data);

  // pulse CA1 low in response
  //Serial.println("Pulsing CB1 LOW...");
  digitalWrite(CB1, LOW);
  digitalWrite(CB1, HIGH);

  //Serial.print("Printing char: ");
  char cc = (char)data;
  Serial.print(cc);
  
  //Serial.println("on_cb2 done.");
}

void loop() 
{
  if(Serial.available())
  {
    //Serial.println("serial data available");
    int data = Serial.read();
    //if((data == 0x0a) || (data > 0x1f && data <= 0x7f)) 
    //{
      //Serial.println("Setting pins A");
      //Serial.print("Sending ");
      //Serial.print((char)data);
      //Serial.print(" ");
      //Serial.println(data);
      //Serial.println("Ready to send...");
      for(int dp=7; dp>-1; dp--)
      {
        digitalWrite(PAX[dp], data & 0x01 ? HIGH : LOW);
        data = data >> 1;
      }
      //Serial.println("Pulsing CA1...");
      digitalWrite(CA1, LOW);
      delayMicroseconds(1);
      digitalWrite(CA1, HIGH);

      // wait for IRQB to go high
      while(!digitalRead(IRQB)) {}
    //}
  }
}
