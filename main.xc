// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define  IMHT 16                  //image height
#define  IMWD 16                  //image width
on tile[0] : in port buttons = XS1_PORT_4E;

typedef unsigned char uchar;      //using uchar as shorthand

int Graph[IMHT][IMWD][2];         // the whole farm
                                  // 2 means there are two graphs in order to write back again.


int ProcessingGraph = 0;          // the index of processing graph. it should be 0 or 1.

int onwhichgraph ;

port p_scl = XS1_PORT_1E;         //interface ports to orientation
port p_sda = XS1_PORT_1F;

#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend c_out)
{
  int res;
  uchar line[ IMWD ];
  printf( "DataInStream: Start...\n" );

  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
    printf( "DataInStream: Error openening %s\n.", infname );
    return;
  }

  //Read image line-by-line and send byte by byte to channel c_out
  for( int y = 0; y < IMHT; y++ ) {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ ) {
      c_out <: line[ x ];
      printf( "-%4.1d ", line[ x ] ); //show image values
    }
    printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  return;
}

/// The function used to calculate the number of living cells given position
/// x is the x-axis
/// y is the y-axis
int AnalyseCell(int x, int y){
    int result = 0;
    int loopCount = 0;
    for (int i = -1; i <= 1; i++){
        for (int j = -1; j <= 1; j++){
            int xd = x + j;
            int yd = y + i;
            if (xd == 16){xd = 0;} else if (xd == -1){xd = 15;}
            if (yd == 16){yd = 0;} else if (yd == -1){yd = 15;}

            if (Graph[xd][yd][ProcessingGraph] == 255){
                result += 1;
            }
            loopCount += 1;
        }
    }
    if (Graph[x][y][ProcessingGraph] == 255){
        result -= 1;
    }
    return result;
}

int RunGraph(){
    ProcessingGraph = 1 - ProcessingGraph;      //swap between 0 and 1
    for(int j = 0; j < IMHT; j++){
        for(int i = 0; i < IMWD; i++){
            int alive = AnalyseCell(i,j);
            int myStatus = Graph[i][j][1-ProcessingGraph];
            if (myStatus == 0){
                if (alive == 3){Graph[i][j][ProcessingGraph] = 255;}
            }
            else {
                if(alive < 2) {Graph[i][j][ProcessingGraph] = 0;}
                if(alive < 4) {Graph[i][j][ProcessingGraph] = Graph[i][j][1-ProcessingGraph];}
                else{Graph[i][j][ProcessingGraph] = 0;}
            }
        }
    }
    return 1;
}

int RunHalfGraph(int segment){
    int startPoint = segment * 8;
    for (int j = startPoint; j < startPoint + 8; j++){
        for(int i = 0; i < IMWD; i++){
            int alive = AnalyseCell(i,j);
            int myStatus = Graph[i][j][1-ProcessingGraph];
            if (myStatus == 0){
                if (alive == 3){Graph[i][j][ProcessingGraph] = 255;}
            }
            else {
                if(alive < 2) {Graph[i][j][ProcessingGraph] = 0;}
                if(alive < 4) {Graph[i][j][ProcessingGraph] = Graph[i][j][1-ProcessingGraph];}
                else{Graph[i][j][ProcessingGraph] = 0;}
            }
        }
    }
}

int RunGraph2(){
    par {
        RunGraph(0);
        RunGraph(1);
    }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////

void distributor(chanend c_in, chanend c_out, chanend fromAcc)
{
  uchar val;

  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Board Tilt...\n" );
  fromAcc :> int value;

  //Read in and do something with your image values..
  //This just inverts every pixel, but you should
  //change the image according to the "Game of Life"
  printf( "Processing...\n" );
  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
    for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
      c_in :> val;                    //read the pixel value
      // initialize the graph
      Graph[x][y][0] = val;   //ProcessingGraph is 0
    }
  }

    int turn = 0;
    while(turn < 1){
        int result = RunGraph();
        turn += 1;
    }

        for(int a = 0; a < 16; a++){
            for(int b = 0; b < 16; b++){
                printf("-%4.1d " , Graph[b][a][ProcessingGraph]);
            }
            printf("\n");
        }
   printf("first run print finished");

}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in)
{
  int res;
  uchar line[ IMWD ];

  //Open PGM file
  printf( "DataOutStream: Start...\n" );
  res = _openoutpgm( outfname, IMWD, IMHT );
  if( res ) {
    printf( "DataOutStream: Error opening %s\n.", outfname );
    return;
  }

  //Compile each line of the image and write the image line-by-line
  for( int y = 0; y < IMHT; y++ ) {
    for( int x = 0; x < IMWD; x++ ) {
      c_in :> line[ x ];
    }
    _writeoutline( line, IMWD );
    printf( "DataOutStream: Line written...\n" );
  }

  //Close the PGM image
  _closeoutpgm();
  printf( "DataOutStream: Done...\n" );
  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////
void orientation( client interface i2c_master_if i2c, chanend toDist) {
  i2c_regop_res_t result;
  char status_data = 0;
  int tilted = 0;

  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }
  
  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  //Probe the orientation x-axis forever
  while (1) {

    //check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    //send signal to distributor after first tilt
    if (!tilted) {
      if (x>30) {
        tilted = 1 - tilted;
        toDist <: 1;
      }
    }
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
void buttonListener(in port b, chanend control) {
  int r;
  while (1) {
    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;    // check if some buttons are pressed
    if ((r==13) || (r==14))     // if either button is pressed
    control <: r;             // send button pattern to userAnt
  }
}

int main(void) {

i2c_master_if i2c[1];               //interface to orientation

char infname[] = "test.pgm";     //put your input image path here
char outfname[] = "testout.pgm"; //put your output image path here
chan c_inIO, c_outIO, c_control;    //extend your channel definitions here

par {
    i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
    orientation(i2c[0],c_control);        //client thread reading orientation data
    DataInStream(infname, c_inIO);          //thread to read in a PGM image
    DataOutStream(outfname, c_outIO);       //thread to write out a PGM image
    distributor(c_inIO, c_outIO, c_control);//thread to coordinate work on image
  }

  return 0;
}
