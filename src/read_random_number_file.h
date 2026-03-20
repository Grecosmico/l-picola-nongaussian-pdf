#include <stdlib.h>
#include <stdio.h>

int read_random_number_file(int Nmesh, float_kind* randoms){

  FILE* datafile;
  char buf[500];
  unsigned blksz64,blksz32,nx,ny,nz;
  unsigned vartype;
  int iseed;
  int addrtype = 32;
  int ferr;

  float* in_float;
  double* in_double;

  float sign4 = -1.0f;
  double sign8 = -1.0;

  printf("Reading random numbers from file %s\n",RandomNumberFilename);

  sprintf(buf, "%s", RandomNumberFilename);

  if(!(datafile = fopen(buf, "r"))) {
    if (ThisTask == 0) printf("\nERROR: Can't read random numbers from file '%s'.\n\n", buf);
    FatalError((char *)"read_random_number_file.h", 25);
  }
  fflush(stdout);

  ferr = fread((char *)(&blksz32), sizeof(int),1,datafile);
  ferr = fread((char *)(&nx), sizeof(unsigned),1,datafile);
  if (blksz32 != 4*sizeof(int) || nx != Nmesh)
  {
    addrtype = 64;
        
    rewind(datafile);
    ferr = fread((char *)(&blksz64), sizeof(int),1,datafile);
    ferr = fread((char *)(&nx), sizeof(unsigned),1,datafile);
        
    if( blksz64 != 4*sizeof(int) || nx != Nmesh )
        addrtype = -1;
  }
  rewind(datafile);

  if (addrtype < 0){
    printf("Wrong grid size of random number file or corrupt file.\n");
    return(1);
  }

  if( addrtype == 32 )
    ferr = fread((char *)(&blksz32),sizeof(int),1,datafile);
  else
    ferr = fread((char *)(&blksz64),sizeof(unsigned),1,datafile);
    
  ferr = fread((char *)(&nx), sizeof(unsigned), 1, datafile);
  ferr = fread((char *)(&ny), sizeof(unsigned), 1, datafile);
  ferr = fread((char *)(&nz), sizeof(unsigned), 1, datafile);
  ferr = fread((char *)(&iseed), sizeof(int), 1, datafile);

  unsigned nzp = 2*(nz/2+1); 

  if ( nx!=Nmesh || ny!=Nmesh || nz!=Nmesh ){
    printf("Dimensions of the random number file do not match grid: %ux%ux%u vs. %d**3\n",nx,ny,nz,Nmesh);
    return(1);
  }

  if( addrtype == 32 )
    ferr = fread((char *)(&blksz32),sizeof(int),1,datafile);
  else
    ferr = fread((char *)(&blksz64),sizeof(unsigned),1,datafile);

  //... read data ...//
  //check whether random numbers are single or double precision numbers
  if( addrtype == 32 )
  {
    ferr = fread((char *)(&blksz32), sizeof(int), 1, datafile);
    if( blksz32 == nx*ny*sizeof(float) ){
      vartype = 4;
    } else if( blksz32 == nx*ny*sizeof(double) ){
      vartype = 8;
    } else {
      printf("corrupt random number file 2\n");
      return(1);
    }
  }else{
    ferr = fread((char *)(&blksz64), sizeof(unsigned), 1, datafile);
    if( blksz64 == nx*ny*sizeof(float) ){
      vartype = 4;
    } else if( blksz64 == nx*ny*sizeof(double) ){
      vartype = 8;
    } else {
      printf("corrupt random number file 3\n");
      return(1);
    }
  }

  //rewind to beginning of block
  if( addrtype == 32 )
    fseek(datafile,-sizeof(int),SEEK_CUR);
  else
    fseek(datafile,-sizeof(unsigned),SEEK_CUR);
	
  if (vartype == 4){
    in_float = malloc(nx*ny*sizeof(float));
  } else {
	in_double = malloc(nx*ny*sizeof(double));
  }

  printf("Random number file contains %d values.\n",nx*ny*nz);
	
  long double sum = 0.0, sum2 = 0.0;
  unsigned count = 0;

  //perform actual reading
  if( vartype == 4 )
  {
    for( int kk=0; kk<(int)nz; ++kk )
    {

      if( addrtype == 32 )
      {
        ferr = fread((char *)(&blksz32), sizeof(int), 1, datafile);
        if( blksz32 != nx*ny*sizeof(float) ){
          printf("corrupt random number file 4\n");
          return(1);
        }
      } else {
        ferr = fread((char *)(&blksz64), sizeof(unsigned), 1, datafile);
        if( blksz64 != nx*ny*sizeof(float) ){
          printf("corrupt random number file 5\n");
          return(1);
        }
      }
		 
	  ferr = fread((char *)&in_float[0], nx*ny*sizeof(float), 1, datafile);
			
      for( int jj=0,q=0; jj<(int)ny; ++jj ){
        for( int ii=0; ii<(int)nx; ++ii ){
          sum += in_float[q];
          sum2 += in_float[q]*in_float[q];
					
          randoms[(ii*ny+jj)*nzp+kk] = sign4 * in_float[q++];
          ++count;
        }
      }
			
      if( addrtype == 32 )
      {
        ferr = fread((char *)(&blksz32), sizeof(int), 1, datafile);
        if( blksz32 != nx*ny*sizeof(float) ){
          printf("corrupt random number file 6\n");
          return(1);
        }
      } else {
        ferr = fread((char *)(&blksz64), sizeof(unsigned), 1, datafile);
        if( blksz64 != nx*ny*sizeof(float) ){
          printf("corrupt random number file 7\n");
          return(1);
        }
      }
    }
  }
  else if( vartype == 8 )
  {
    for( int kk=0; kk<(int)nz; ++kk )
    {
	  if( addrtype == 32 )
      {
        ferr = fread((char *)(&blksz32), sizeof(int), 1, datafile);
        if( blksz32 != nx*ny*sizeof(double) ){
          printf("corrupt random number file 8\n");
          return(1);
        }
      } else {
        ferr = fread((char *)(&blksz64), sizeof(unsigned), 1, datafile);
        if( blksz64 != nx*ny*sizeof(double) ){
          printf("corrupt random number file 9\n");
          return(1);
        }
      }

      ferr = fread((char *)&in_double[0], nx*ny*sizeof(double), 1, datafile);
			
      for( int jj=0,q=0; jj<(int)ny; ++jj ){
        for( int ii=0; ii<(int)nx; ++ii )
		{
          sum += in_double[q];
          sum2 += in_double[q]*in_double[q];

          randoms[(ii*ny+jj)*nzp+kk] = sign8 * in_double[q++];
          ++count;
        }
      }

      if( addrtype == 32 )
      {
        ferr = fread((char *)(&blksz32), sizeof(int), 1, datafile);
        if( blksz32 != nx*ny*sizeof(double) ){
          printf("corrupt random number file 10\n");
          return(1);
        }
      } else {
        ferr = fread((char *)(&blksz64), sizeof(unsigned), 1, datafile);
        if( blksz64 != nx*ny*sizeof(double) ){
          printf("corrupt random number file 11\n");
          return(1);
        }
      }
    }
  }

  double mean, var;
  mean = sum/count;
  var = sum2/count-mean*mean;
	
  printf("Random numbers in file have \n     mean = %f and var = %f\n", mean, var);

  fclose(datafile);

  if (vartype == 4){
    free(in_float);
  } else {
	free(in_double);
  }
  return(0);
}


