const int ADDR_START = 38;
const int DATA_START = 22;
const int CLOCK = 2;
const int OP_START= 3;
const int RW = 5;
const int RAM0 = 8;
const int RAM1 = 9;
const int ROM = 10;
const int VIA = 7;
const int IRQ = 32;


void setup() {
  pinMode(CLOCK, INPUT);
  pinMode(OP_START, INPUT);
  pinMode(RW, INPUT);
  pinMode(RAM0, INPUT);
  pinMode(RAM1, INPUT);
  pinMode(ROM, INPUT);
  pinMode(VIA, INPUT);
  pinMode(IRQ, INPUT);
  for(int i=0; i<16; ++i)
  {
    pinMode(ADDR_START+i, INPUT);
  }
  for(int i=0; i<8; ++i)
  {
    pinMode(DATA_START+i, INPUT);
  }

  attachInterrupt(digitalPinToInterrupt(CLOCK), onClock, RISING);
  Serial.begin(57600);
}

void loop() {
}

void onClock()
{
  int clk = digitalRead(CLOCK) ? 1 : 0;
  char opstart = digitalRead(OP_START) ? '*' : ' ';
  char rw = digitalRead(RW) ? 'r' : 'W';
  int ram0 = digitalRead(RAM0) ? 1 : 0;
  int ram1 = digitalRead(RAM1) ? 1 : 0;
  int rom = digitalRead(ROM) ? 1 : 0;
  int via = digitalRead(VIA) ? 1 : 0;
  int irq = digitalRead(IRQ) ? ' ' : 'I';
  
  int address = 0;
  for(int i=0; i<16; ++i)
  {    
    address |= (digitalRead(ADDR_START+i) ? 1 : 0) << i;    
  }
  
  int data= 0;
  for(int i=0; i<8; ++i)
  {    
    data |= (digitalRead(DATA_START+i) ? 1 : 0) << i;    
  }

  char buf[512];
  sprintf(buf, "%c %04x %c %02x %c ram0:%d ram1:%d rom:%d via:%d", opstart, address, rw, data,irq,ram0,ram1,rom,via);
  Serial.println(buf);
}
