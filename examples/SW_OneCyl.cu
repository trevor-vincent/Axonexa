#define WARP_SIZE 32
#define USE_DOUBLE
#define SPECULAR_REFLECTION
//#define USE_RELAXATION
#define GAMMA 267500.0 // ms^-1 * T^-1
#define PI 3.1415926535897932384626433832795
//#define USE_RELAXATION

#include <assert.h>
#include <cuda.h>
#include <curand_kernel.h>
#include <cmath>
#include <iostream>
#include <iomanip>
#include <vector>
#include <time.h>
#include <algorithm>

#if defined USE_DOUBLE
typedef double real;
#define EPSILON 1e-14

#else
typedef float real;
#define EPSILON 1e-6

#endif

using namespace std;

#include "misc.cuh"
#include "vector3.cuh"
#include "cudaVector.cuh"
#include "timer.cuh"
#include "compare.cuh"
#include "pinnedVector.cuh"
#include "cudaVector.cu"
#include "pinnedVector.cu"
#include "bfunctors.cuh"
#include "substrate.cuh"
#include "cylinderXY.cuh"
#include "Sphere.cuh"
#include "plane.cuh"
#include "empty.cuh"
#include "lattice.cuh"
#include "simuparams.cuh"
#include "boundaryCheck.cuh"
#include "kernelSetup.cuh"
#include "kernelMag.cuh"
#include "kernelDEBUG.cuh"
#include "kernelPhase.cuh"
#include "kernelLattice.cuh"
#include "kernelWC.cuh"
#include "CPUkernels.cuh"
#include "gfunctors.cuh"
#include "phaseAcquisition.cuh"
#include "phaseAcquisitionStream.cuh"
#include "magAcquisition.cuh"
#include "magAcquisitionStream.cuh"
#include "blochdiff.cuh"
#include "nr3.h"
#include "ran.h"
#include "gamma.h"
#include "deviates.h"
#include "RPSinitializer.h"



int main (){

  cudaFuncSetCacheConfig( "updateWalkersMag", cudaFuncCachePreferL1 );
  cudaFuncSetCacheConfig( "setup_kernel", cudaFuncCachePreferL1 );
  cudaFuncSetCacheConfig( "_functionReduceAtom", cudaFuncCachePreferShared );

  int number_of_particles = 57344; //needs to be a factor of two
  real timestep = .001;  

  int threads = 128;
  int blocks = number_of_particles/threads;
	
  phaseAcquisitionStream<SWOGSEFunc> pas(number_of_particles);
  phaseAcquisitionStream<SWOGSEFunc> pas1; 
  phaseAcquisitionStream<SWOGSEFunc> pas2;
  phaseAcquisitionStream<SWOGSEFunc> pas3;
  phaseAcquisitionStream<SWOGSEFunc> pas4;
  phaseAcquisitionStream<SWOGSEFunc> pas5;
  phaseAcquisitionStream<SWOGSEFunc> pas6;
  phaseAcquisitionStream<SWOGSEFunc> pas7;
  phaseAcquisitionStream<SWOGSEFunc> pas8;
  phaseAcquisitionStream<SWOGSEFunc> pas9;
  phaseAcquisitionStream<SWOGSEFunc> pas10;
  
   int NOI = 20;
   int NOM = 20;

 	real gradient_duration = 30;	
	real gradient_spacing  = 2.0;
	real echo_time = 2.0*gradient_duration + gradient_spacing ;
	int number_of_timesteps = (int) (echo_time/timestep);		
    phaseAcquisition<SWOGSEFunc> pa(NOM*NOI,number_of_timesteps,number_of_particles,time(NULL));
	
	for (int j = 0; j < NOI; j++){
		for (int i = 0; i < NOM; i++) {
			int N = 1+j;
			real G = i*0.0000025*N;
			SWOGSEFunc cosGRAD(G, gradient_duration,gradient_spacing, N, Vector3(1.0,0.0,0.0));
			pa.addMeasurement(cosGRAD);			
		}
	}
	
	pas.addAcquisition(pa);

	real radius = .0015;
	real D_extra = 2.5E-6;
	real D_intra = 1.0E-6;
	real T2_i = 200;
	real T2_e = 200;
	real f = .6;
	real a = sqrt( PI*radius*radius / f );

	
	std::vector<Cylinder_XY> basis(1);
	Lattice lattice(a, a, a, T2_e, 0.0, D_extra,1);
	basis[0] = Cylinder_XY(a/2.0, a/2.0,  radius,  T2_i,0.0, D_intra, 1, 0.0, EPSILON);
/*	
	std::vector<Cylinder_XY> basis;
	Lattice lattice(cube_length, cube_length, cube_length, T2_e, 0.0, D_extra,100);
	RPSLatticeInitializer<Cylinder_XY> rpsli(lattice,0);
	rpsli.gammaRadialDist( 12344124, alpha,  beta, .0001, cube_length/10);
	rpsli.uniformCenterDist( 12344213* 5 );
	rpsli.setRegions();
	rpsli.correctEdges();
	lattice = rpsli.lat; //needed to reinitialize basis size (since it was initialized to 100 and there will be > 100 cylinders).
	
	// if (rpsli.basis.size() != 100){std::cout << " Basis Size Does not equal 100 " << std::endl;}
	// std::cout << "lattice basis size = " << lattice.getBasisSize() << std::endl;
	for (int i = 0; i < rpsli.basis.size(); i++){
		basis.push_back(Cylinder_XY(0.0, 0.0, 0.0,  T2_i,0.0, D_intra, i+1, 0.0));
		basis[i].setRadius(rpsli.basis[i].getRadius() );
		basis[i].setCenter(rpsli.basis[i].getCenter() );
		basis[i].setEPS( (1E-13));
		basis[i].setRegion(rpsli.basis[i].getRegion());
		std::cout << rpsli.basis[i].getCenter()  << "  " << rpsli.basis[i].getRadius() << " " << std::endl;
		
	}	
	
*/

  std::vector<int> plan(3); plan[0] = 0; plan[1] = NOI;  plan[2] = NOI;
  std::vector<int> numOfSMPerDevice(1); numOfSMPerDevice[0] = 14; numOfSMPerDevice[1] = 2; 


  pas1 = pas; pas1.getAcquisition(0).getSeed() *= 2;
   pas2 = pas; pas2.getAcquisition(0).getSeed() *= 3;
   pas3 = pas; pas3.getAcquisition(0).getSeed() *= 4;
   pas4 = pas; pas4.getAcquisition(0).getSeed() *= 5;
   pas5 = pas; pas4.getAcquisition(0).getSeed() *= 6;
   pas6 = pas; pas4.getAcquisition(0).getSeed() *= 7;
   pas7 = pas; pas4.getAcquisition(0).getSeed() *= 8;
   pas8 = pas; pas4.getAcquisition(0).getSeed() *= 9;
   pas9 = pas; pas4.getAcquisition(0).getSeed() *= 10;
  
   pas.runAcquisitionLattice(0, &basis[0], lattice,  timestep, blocks, threads, 14);
   pas1.runAcquisitionLattice(0, &basis[0], lattice,  timestep, blocks, threads, 14);
   pas2.runAcquisitionLattice(0, &basis[0], lattice,  timestep, blocks, threads, 14);
   pas3.runAcquisitionLattice(0, &basis[0], lattice,  timestep, blocks, threads, 14);
   pas4.runAcquisitionLattice(0, &basis[0], lattice,  timestep, blocks, threads, 14);
   pas5.runAcquisitionLattice(0, &basis[0], lattice,  timestep, blocks, threads, 14);
   pas6.runAcquisitionLattice(0, &basis[0], lattice,  timestep, blocks, threads, 14);
   pas7.runAcquisitionLattice(0, &basis[0], lattice,  timestep, blocks, threads, 14);
   pas8.runAcquisitionLattice(0, &basis[0], lattice,  timestep, blocks, threads, 14);
   pas9.runAcquisitionLattice(0, &basis[0], lattice,  timestep, blocks, threads, 14);

  std::cout << std::endl << " Signals " << std::endl;
 
  for (int j = 0; j < NOI*NOM; j++){
	std::cout << setprecision(20);
	std::cout << pas.getAcquisition(0).getGradientFunctors()[j].getFreq() << " " ;
	std::cout << pas.getAcquisition(0).getGradientFunctors()[j].getG() << " " ;
	std::cout << pas.getAcquisition(0).getMx()[j] << " " << pas.getAcquisition(0).getMy()[j] << " " ;
	std::cout << pas1.getAcquisition(0).getMx()[j] << " " << pas1.getAcquisition(0).getMy()[j] << " " ;
	std::cout << pas2.getAcquisition(0).getMx()[j] << " " << pas2.getAcquisition(0).getMy()[j] << " " ;
	std::cout << pas3.getAcquisition(0).getMx()[j] << " " << pas3.getAcquisition(0).getMy()[j] << " " ;
	std::cout << pas4.getAcquisition(0).getMx()[j] << " " << pas4.getAcquisition(0).getMy()[j] << " " ;
	std::cout << pas5.getAcquisition(0).getMx()[j] << " " << pas5.getAcquisition(0).getMy()[j] << " " ;
	std::cout << pas6.getAcquisition(0).getMx()[j] << " " << pas6.getAcquisition(0).getMy()[j] << " " ;
	std::cout << pas7.getAcquisition(0).getMx()[j] << " " << pas7.getAcquisition(0).getMy()[j] << " " ;
	std::cout << pas8.getAcquisition(0).getMx()[j] << " " << pas8.getAcquisition(0).getMy()[j] << " " ;
	std::cout << pas9.getAcquisition(0).getMx()[j] << " " << pas9.getAcquisition(0).getMy()[j] << " " ;
	std::cout << std::endl;
  }


  
 
}
