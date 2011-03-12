/* BDDCML - Multilevel BDDC
 * Copyright (C) The BDDCML Team
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 * ____________________________________________________________________*/

#include "parmetis.h"
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

# if defined(UPPER) 
#  define F_SYMBOL(lower_case,upper_case) upper_case
# elif defined(Add_)
#  define F_SYMBOL(lower_case,upper_case) lower_case##_
# elif defined(Add__)
#  define F_SYMBOL(lower_case,upper_case) lower_case##__
# else
#  define F_SYMBOL(lower_case,upper_case) lower_case
# endif

/*****************************************
* Function for construction of parallel graph and detecting subdomain neigbours based on it
* derived from ParMETIS function ParMETIS_V3_PartMeshKway
* uses ParMETIS just to obtain the parallel graph
* Jakub Sistek 2010
******************************************/

#define pget_sub_neighbours_c \
    F_SYMBOL(pget_sub_neighbours_c,PGET_SUB_NEIGHBOURS_C)
void pget_sub_neighbours_c(int *elmdist, int *eptr, int *eind, 
                           int *numflag, int *ncommonnodes, 
			   int *iets, int *liets,
			   int *nsub, int *nsub_loc, int *sub_start,
			   int *kadjsub, int *lkadjsub, int *debug,
		           MPI_Comm *comm)
{
  int *xadj, *adjncy;
  int myid;
  int nver_loc, ivl, iv, isub, ineig, nneig, indneig, isub_loc, isubneig, point;

  /********************************/
  /* Try and take care bad inputs */
  /********************************/
  if (elmdist == NULL || eptr == NULL || eind == NULL || 
      numflag == NULL || ncommonnodes == NULL ||
      iets == NULL || liets == NULL ||
      nsub == NULL || nsub_loc == NULL || sub_start == NULL ||
      kadjsub == NULL || lkadjsub == NULL || debug == NULL || comm == NULL) {
     printf("ERROR: One or more required parameters is NULL. Aborting.\n");
     abort();
  }

  MPI_Comm_rank(*comm,&myid);

  if (debug) {
     if (myid == 0) {
        printf("   calling Mesh2Dual to get dual graph ...");
     }
  }
  ParMETIS_V3_Mesh2Dual(elmdist, eptr, eind, numflag, ncommonnodes, &xadj, &adjncy, comm);
  if (debug) {
     if (myid == 0) {
        printf(" done. \n");
	fflush(stdout);
     }
  }

  /***********************/
  /* Mark the neighbours */
  /***********************/


  nver_loc = elmdist[myid+1] - elmdist[myid];
  if (debug) {
     printf("myid = %d , nver_loc = %d \n",myid,nver_loc);
  }
  for (ivl = 0; ivl < nver_loc; ivl++) {
     iv = elmdist[myid] + ivl;
     isub = iets[iv - *numflag];

     if (isub < *sub_start || isub > *sub_start + *nsub_loc - 1) {
        printf("ERROR: Subdomain %d out of range for processor %d \n",isub,myid);
	fflush(stdout);
        abort();
     }
     
     nneig = xadj[ivl+1] - xadj[ivl];
     for (ineig = 0; ineig < nneig; ineig++) {
	indneig = adjncy[xadj[ivl] - *numflag + ineig];
        
	isubneig = iets[indneig-1];
        /*printf("myid = %d , indneig = %d, isubneig = %d \n",myid,indneig,isubneig);*/
	if (isub != isubneig) {
	   isub_loc = isub - *sub_start + 1;

	   point = (isub_loc-1) * *nsub;

	   kadjsub[point + isubneig - *numflag] = 1;
	}
     }
  }

  free(xadj);
  free(adjncy);

  return;
}
