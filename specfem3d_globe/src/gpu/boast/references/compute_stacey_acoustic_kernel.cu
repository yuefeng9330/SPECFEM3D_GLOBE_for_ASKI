// from compute_stacey_acoustic_cuda.cu
#define NGLLX 5
#define NGLL2 25
#define INDEX2(xsize,x,y) x + (y)*xsize
#define INDEX4(xsize,ysize,zsize,x,y,z,i) x + xsize*(y + ysize*(z + zsize*i))

typedef float realw;

__global__ void compute_stacey_acoustic_kernel(realw* potential_dot_acoustic,
                                               realw* potential_dot_dot_acoustic,
                                               int interface_type,
                                               int num_abs_boundary_faces,
                                               int* abs_boundary_ispec,
                                               int* nkmin_xi,
                                               int* nkmin_eta,
                                               int* njmin,
                                               int* njmax,
                                               int* nimin,
                                               int* nimax,
                                               realw* abs_boundary_jacobian2D,
                                               realw* wgllwgll,
                                               int* ibool,
                                               realw* vpstore,
                                               int SAVE_FORWARD,
                                               realw* b_absorb_potential) {

  int igll = threadIdx.x;
  int iface = blockIdx.x + gridDim.x*blockIdx.y;

  int i,j,k,iglob,ispec;
  realw sn;
  realw jacobianw,fac1;

  // don't compute points outside NGLLSQUARE==NGLL2==25
  // way 2: no further check needed since blocksize = 25
  if (iface < num_abs_boundary_faces){

  //  if(igll<NGLL2 && iface < num_abs_boundary_faces) {

    // "-1" from index values to convert from Fortran-> C indexing
    ispec = abs_boundary_ispec[iface]-1;

    // determines indices i,j,k depending on absorbing boundary type
    switch( interface_type ){
      case 4:
        // xmin
        if (nkmin_xi[INDEX2(2,0,iface)] == 0 || njmin[INDEX2(2,0,iface)] == 0) return;

        i = 0; // index -1
        k = (igll/NGLLX);
        j = (igll-k*NGLLX);

        if (k < nkmin_xi[INDEX2(2,0,iface)]-1 || k > NGLLX-1) return;
        if (j < njmin[INDEX2(2,0,iface)]-1 || j > njmax[INDEX2(2,0,iface)]-1) return;

        fac1 = wgllwgll[k*NGLLX+j];
        break;

      case 5:
        // xmax
        if (nkmin_xi[INDEX2(2,1,iface)] == 0 || njmin[INDEX2(2,1,iface)] == 0) return;

        i = NGLLX-1;
        k = (igll/NGLLX);
        j = (igll-k*NGLLX);

        if (k < nkmin_xi[INDEX2(2,1,iface)]-1 || k > NGLLX-1) return;
        if (j < njmin[INDEX2(2,1,iface)]-1 || j > njmax[INDEX2(2,1,iface)]-1) return;

        fac1 = wgllwgll[k*NGLLX+j];
        break;

      case 6:
        // ymin
        if (nkmin_eta[INDEX2(2,0,iface)] == 0 || nimin[INDEX2(2,0,iface)] == 0) return;

        j = 0;
        k = (igll/NGLLX);
        i = (igll-k*NGLLX);

        if (k < nkmin_eta[INDEX2(2,0,iface)]-1 || k > NGLLX-1) return;
        if (i < nimin[INDEX2(2,0,iface)]-1 || i > nimax[INDEX2(2,0,iface)]-1) return;

        fac1 = wgllwgll[k*NGLLX+i];
        break;

      case 7:
        // ymax
        if (nkmin_eta[INDEX2(2,1,iface)] == 0 || nimin[INDEX2(2,1,iface)] == 0) return;

        j = NGLLX-1;
        k = (igll/NGLLX);
        i = (igll-k*NGLLX);

        if (k < nkmin_eta[INDEX2(2,1,iface)]-1 || k > NGLLX-1) return;
        if (i < nimin[INDEX2(2,1,iface)]-1 || i > nimax[INDEX2(2,1,iface)]-1) return;

        fac1 = wgllwgll[k*NGLLX+i];
        break;

      case 8:
        // zmin
        k = 0;
        j = (igll/NGLLX);
        i = (igll-j*NGLLX);

        if (j < 0 || j > NGLLX-1) return;
        if (i < 0 || i > NGLLX-1) return;

        fac1 = wgllwgll[j*NGLLX+i];
        break;

    }

    iglob = ibool[INDEX4(5,5,5,i,j,k,ispec)]-1;

    // determines bulk sound speed
    // velocity
    sn = potential_dot_acoustic[iglob] / vpstore[INDEX4(NGLLX,NGLLX,NGLLX,i,j,k,ispec)] ;

    // gets associated, weighted jacobian
    jacobianw = abs_boundary_jacobian2D[INDEX2(NGLL2,igll,iface)]*fac1;

    // Sommerfeld condition
    atomicAdd(&potential_dot_dot_acoustic[iglob],-sn*jacobianw);

    // adjoint simulations
    if (SAVE_FORWARD){
      // saves boundary values
      b_absorb_potential[INDEX2(NGLL2,igll,iface)] = sn*jacobianw;
    }

  }
}

