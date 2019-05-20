/* pgmmonths.c - extracts a month (or mean of months) from a montage PGM */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAXGRID 99999

main(int argc, char **argv) {
  int total[MAXGRID],count[MAXGRID];
  int c,i,month,want;
  int startmonth,endmonth,nmonths;
  int gridx,gridy,gridsize;
  char s[99];
  
  if(argc!=3) {
    fprintf(stderr,"Usage: pgmmonths startmonth endmonth\n");
    exit(1);
  }
  startmonth = atoi(argv[1]);
  endmonth = atoi(argv[2]);
  nmonths = endmonth-startmonth+1;
  if(startmonth>endmonth) 
    nmonths += 12;

  fgets(s,99,stdin);
  scanf("%d %d\n",&gridx,&gridy);
  fgets(s,99,stdin);
  gridy /= 12;
  gridsize = gridx*gridy;
  if(gridsize<1||gridsize>MAXGRID) {
    fprintf(stderr,"Error in pgmmonths\n%d %d\n",gridx,gridy);
    exit(1);
  }
  
  for(i=0;i<gridsize;i++) {
    total[i] = 0;
    count[i] = 0;
  }
  
  for(month=1;month<=12;month++) {
    want = 0;
    if(endmonth>=startmonth) {
      if(month>=startmonth && month<=endmonth)
        want = 1;
    } else {
      /* wraparound year */
      if(month<=endmonth || month>=startmonth)
        want = 1;
    }
    /*if(want) fprintf(stderr,"Month %2d\n",month);*/
    for(i=0;i<gridsize;i++) {
      c = getchar();
      if(want) {
        if(c!=255) {
          total[i] += c;
          count[i] ++;
        }
      }
    }
  }
  
  printf("P5\n%d %d\n255\n",gridx,gridy);
  
  for(i=0;i<gridsize;i++) {
    if(count[i]==0) {
      putchar(255);
    } else {
      putchar(total[i]/count[i]);
    }
  }
}

