#define WARP_SIZE 32
#define USE_DOUBLE
#define SPECULAR_REFLECTION
//#define USE_RELAXATION
#define GAMMA 267500.0 // ms^-1 * T^-1
#define PI 3.1415926535897932384626433832795
//#define USE_RELAXATION

#include <algorithm>
#include <assert.h>
#include <cmath>
#include <cuda.h>
#include <curand_kernel.h>
#include <iomanip>
#include <iostream>
#include <time.h>
#include <vector>

#if defined USE_DOUBLE
typedef double real;
#define EPSILON 1e-14

#else
typedef float real;
#define EPSILON 1e-6

#endif

using namespace std;

#include "CPUkernels.cuh"
#include "RPSinitializer.h"
#include "Sphere.cuh"
#include "bfunctors.cuh"
#include "blochdiff.cuh"
#include "boundaryCheck.cuh"
#include "compare.cuh"
#include "cudaVector.cu"
#include "cudaVector.cuh"
#include "cylinderXY.cuh"
#include "deviates.h"
#include "empty.cuh"
#include "gamma.h"
#include "gfunctors.cuh"
#include "kernelDEBUG.cuh"
#include "kernelLattice.cuh"
#include "kernelMag.cuh"
#include "kernelPhase.cuh"
#include "kernelSetup.cuh"
#include "kernelWC.cuh"
#include "lattice.cuh"
#include "magAcquisition.cuh"
#include "magAcquisitionStream.cuh"
#include "misc.cuh"
#include "nr3.h"
#include "phaseAcquisition.cuh"
#include "phaseAcquisitionStream.cuh"
#include "pinnedVector.cu"
#include "pinnedVector.cuh"
#include "plane.cuh"
#include "ran.h"
#include "simuparams.cuh"
#include "substrate.cuh"
#include "timer.cuh"
#include "vector3.cuh"

int main() {

    real D_extra = 2.5E-6;
    real D_intra = 1.0E-6;
    real T2_i = 200;
    real T2_e = 200;

    real cube_length = .0365;
    real alpha = .00691;     // alpha = k
    real beta = 1.0 / 2.331; // beta = 1/theta
    real radmin = 2.0 * sqrt(6.0 * D_extra * .001);

    std::vector<Cylinder_XY> basis;
    Lattice lattice(cube_length, cube_length, cube_length, T2_e, 0.0, D_extra,
                    100);
    RPSLatticeInitializer<Cylinder_XY> rpsli(lattice, 0, true);
    int seed1 = time(NULL);
    rpsli.gammaRadialDist(seed1, alpha, beta, radmin, cube_length / 7.);
    int seed2 = time(NULL) * 2;
    while (!rpsli.uniformCenterDist(1208993908, 500)) {
        std::cout << "FAILED TO MAKE CENTER DISTRIBUTION" << std::endl;
        seed2 = time(NULL);
        seed2 *= 4;
    }

    rpsli.setRegions();
    rpsli.correctEdges();
    lattice =
        rpsli.lat; // needed to reinitialize basis size (since it was
                   // initialized to 100 and there will be > 100 cylinders).

    // if (rpsli.basis.size() != 100){std::cout << " Basis Size Does not equal
    // 100 " << std::endl;} std::cout << "lattice basis size = " <<
    // lattice.getBasisSize() << std::endl;
    for (int i = 0; i < rpsli.basis.size(); i++) {
        basis.push_back(
            Cylinder_XY(0.0, 0.0, 0.0, T2_i, 0.0, D_intra, i + 1, 0.0));
        basis[i].setRadius(rpsli.basis[i].getRadius());
        basis[i].setCenter(rpsli.basis[i].getCenter());
        basis[i].setEPS((1E-13));
        basis[i].setRegion(rpsli.basis[i].getRegion());
        std::cout << rpsli.basis[i].getCenter() << "  "
                  << rpsli.basis[i].getRadius() << " " << std::endl;
    }

    std::cout << "VI = " << rpsli.getVI() << std::endl;
    std::cout << "successful with seed for (radii,centers) = (" << seed1
              << " , " << seed2 << " ) " std::endl;
}
