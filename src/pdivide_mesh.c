/* BDDCML - Multilevel BDDC
 *
 * This program is a free software.
 * You can redistribute it and/or modify it under the terms of 
 * the GNU Lesser General Public License 
 * as published by the Free Software Foundation, 
 * either version 3 of the license, 
 * or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details
 * <http://www.gnu.org/copyleft/lesser.html>.
 *_______________________________________________________________*/

#include "parmetis.h"
#include "mpi.h"
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
* Wrapper of ParMETIS_V3_PartMeshKway
* used to convert communicator from Fortran number to whatever type it is in MPI_Comm
* Jakub Sistek 2011
******************************************/

#define pdivide_mesh_c \
    F_SYMBOL(pdivide_mesh_c,PDIVIDE_MESH_C)
void pdivide_mesh_c( idxtype *elmdist, idxtype *eptr, idxtype *eind, idxtype *elmwgt, 
	             int *wgtflag, int *numflag, int *ncon, int *ncommonnodes, int *nparts, 
	             float *tpwgts, float *ubvec, int *options, int *edgecut, idxtype *part, 
	             MPI_Fint *commInt )
{
  MPI_Comm comm;

  /***********************************/
  /* Try and take care of bad inputs */
  /***********************************/
  if (elmdist == NULL || eptr == NULL || eind == NULL || 
      numflag == NULL || ncommonnodes == NULL ||
      nparts == NULL || options == NULL || edgecut == NULL ||
      part == NULL || commInt == NULL ) {
     printf("ERROR: One or more required parameters is NULL. Aborting.\n");
     abort();
  }

  /* portable change of Fortran communicator into C communicator */
  comm = MPI_Comm_f2c( *commInt );

  ParMETIS_V3_PartMeshKway( elmdist,eptr,eind,elmwgt,wgtflag,numflag,ncon,ncommonnodes, nparts, tpwgts, ubvec, options,
                            edgecut, part, &comm );
  return;
}