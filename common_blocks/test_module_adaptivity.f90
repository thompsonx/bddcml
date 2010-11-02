program test_module_adaptivity
! Tester of module_adaptivity
      use module_pp
      use module_adaptivity
      use module_dd
      use module_utils

      implicit none
      include "mpif.h"

      integer,parameter :: kr = kind(1.D0)

      ! parallel variables
      integer :: myid, comm_self, comm_all, nproc, ierr

      integer :: idpar, idpair, idcn, idglb
      integer :: npair

      integer :: matrixtype
      ! how many pairs are assigned to a processor
      integer :: npair_locx
      integer :: ndim, nsub, nelem, ndof, nnod, nnodc, linet
      integer :: nsub_loc

      integer ::             lnndf_coarse
      integer,allocatable ::  nndf_coarse(:)
      integer :: ncnodes, nedge, nface, nglb

      integer ::             lnnglb
      integer,allocatable ::  nnglb(:)
      integer ::             linglb
      integer,allocatable ::  inglb(:)


      integer :: isub, isub_loc, glob_type
      logical :: remove_original 

      character(90)  :: problemname 
      character(100) :: name
      character(100) :: filename

      real(kr) :: timeaux, timeaux1, timeaux2

      integer ::                         lsubdomains
      type(subdomain_type),allocatable :: subdomains(:)
      integer ::             lsub2proc
      integer,allocatable ::  sub2proc(:)
      integer ::             lindexsub
      integer,allocatable ::  indexsub(:)


      ! MPI initialization
!***************************************************************PARALLEL
      call MPI_INIT(ierr)
      ! Communicator
      comm_all  = MPI_COMM_WORLD
      comm_self = MPI_COMM_SELF
      call MPI_COMM_RANK(comm_all,myid,ierr)
      call MPI_COMM_SIZE(comm_all,nproc,ierr)
!***************************************************************PARALLEL

! Initial screen
      if (myid.eq.0) then
         write(*,'(a)') 'ADAPTIVITY TESTER'
         write(*,'(a)') '================='

! Name of the problem
   10    write(*,'(a,$)') 'Name of the problem: '
         read(*,*) problemname
         if(problemname.eq.' ') goto 10

      end if
! Broadcast of name of the problem      
!***************************************************************PARALLEL
      call MPI_BCAST(problemname, 90, MPI_CHARACTER, 0, comm_all, ierr)
!***************************************************************PARALLEL

      if (myid.eq.0) then
         name = trim(problemname)//'.PAR'
         call allocate_unit(idpar)
         open (unit=idpar,file=name,status='old',form='formatted')
      end if

! Reading basic properties 
      if (myid.eq.0) then
         read(idpar,*) ndim, nsub, nelem, ndof, nnod, nnodc, linet
      end if
! Broadcast basic properties of the problem
!***************************************************************PARALLEL
      call MPI_BCAST(ndim,     1, MPI_INTEGER,         0, comm_all, ierr)
      call MPI_BCAST(nsub,     1, MPI_INTEGER,         0, comm_all, ierr)
      call MPI_BCAST(nelem,    1, MPI_INTEGER,         0, comm_all, ierr)
      call MPI_BCAST(ndof,     1, MPI_INTEGER,         0, comm_all, ierr)
      call MPI_BCAST(nnod,     1, MPI_INTEGER,         0, comm_all, ierr)
      call MPI_BCAST(nnodc,    1, MPI_INTEGER,         0, comm_all, ierr)
      call MPI_BCAST(linet,    1, MPI_INTEGER,         0, comm_all, ierr)
!***************************************************************PARALLEL

      ! open file with description of pairs
      if (myid.eq.0) then
         filename = trim(problemname)//'.PAIR'
         call allocate_unit(idpair)
         open (unit=idpair,file=filename,status='old',form='formatted')
      end if
   
      ! SPD matrix
      matrixtype = 1

!*******************************************AUX
! Measure time spent in DD module
      call MPI_BARRIER(comm_all,ierr)
      timeaux1 = MPI_WTIME()
!*******************************************AUX

      lsub2proc = nproc + 1
      allocate(sub2proc(lsub2proc))
      call pp_distribute_subdomains(nsub,nproc,sub2proc,lsub2proc)
      nsub_loc = sub2proc(myid+2) - sub2proc(myid+1)
      lsubdomains = nsub_loc
      lindexsub   = nsub_loc
      allocate(subdomains(nsub_loc),indexsub(lindexsub))
      do isub_loc = 1,nsub_loc
         indexsub(isub_loc) = sub2proc(myid+1) + isub_loc - 1
      end do
      do isub_loc = 1,nsub_loc
         isub = indexsub(isub_loc)

         call dd_init(subdomains(isub_loc),isub,nsub,comm_all)
         call dd_read_mesh_from_file(subdomains(isub_loc),trim(problemname))
         ! SPD matrix
         matrixtype = 1
         call dd_read_matrix_from_file(subdomains(isub_loc),matrixtype,trim(problemname))
         call dd_assembly_local_matrix(subdomains(isub_loc))
         remove_original = .false.
         call dd_matrix_tri2blocktri(subdomains(isub_loc),remove_original)
         call dd_prepare_schur(subdomains(isub_loc),comm_self)
      end do

! create coarse mesh 
! read second level
      if (myid.eq.0) then
         name = trim(problemname)//'.CN'
         write(*,*) 'Reading data from file ',trim(name)
         call allocate_unit(idcn)
         open (unit=idcn,file=name,status='old',form='formatted')
         read(idcn,*) nnodc
         close (idcn)
         name = trim(problemname)//'.GLB'
         write(*,*) 'Reading data from file ',trim(name)
         call allocate_unit(idglb)
         open (unit=idglb,file=name,status='old',form='formatted')
         read(idcn,*) nglb,linglb
         lnnglb = nglb
         allocate(nnglb(lnnglb),inglb(linglb))
         read(idglb,*) inglb
         read(idglb,*) nnglb
         read(idglb,*) nedge, nface
         close(idglb)
         deallocate(nnglb,inglb)
      end if
!*****************************************************************MPI
      call MPI_BCAST(nnodc,1, MPI_INTEGER, 0, comm_all, ierr)
      call MPI_BCAST(nedge,1, MPI_INTEGER, 0, comm_all, ierr)
      call MPI_BCAST(nface,1, MPI_INTEGER, 0, comm_all, ierr)
!*****************************************************************MPI
       
      ncnodes = nnodc + nedge + nface

      ! prepare array of number of coarse dof in generalized coarse nodes
      lnndf_coarse = ncnodes
      allocate(nndf_coarse(lnndf_coarse))

      nndf_coarse = 0
      ! corners contain ndim coarse dof
      nndf_coarse(1:nnodc) = ndim
      ! edges contain ndim coarse dof
      nndf_coarse(nnodc+1:nnodc+nedge) = ndim


      ! auxiliary routine, until reading directly the globs
      do isub_loc = 1,nsub_loc
         call dd_construct_cnodes(subdomains(isub_loc))
      end do

      ! load arithmetic averages on edges
      glob_type = 2
      do isub_loc = 1,nsub_loc
         call dd_load_arithmetic_constraints(subdomains(isub_loc),glob_type)
      end do

      ! prepare matrix C
      do isub_loc = 1,nsub_loc
         call dd_embed_cnodes(subdomains(isub_loc),nndf_coarse,lnndf_coarse)
         call dd_prepare_c(subdomains(isub_loc))
      end do

!*******************************************AUX
! Measure time spent in DD module
      call MPI_BARRIER(comm_all,ierr)
      timeaux2 = MPI_WTIME()
      timeaux = timeaux2 - timeaux1
      if (myid.eq.0) then
         write(*,*) '***************************************'
         write(*,*) 'Time spent in DD setup is ',timeaux,' s'
         write(*,*) '***************************************'
      end if
!*******************************************AUX
!      do isub = 1,nsub
!         call dd_get_interface_size(myid,isub,ndofi,nnodi)
!         lschur = ndofi*ndofi
!         allocate (schur(lschur))
!         call dd_get_schur(myid, isub, schur,lschur)
!         print *,'Schur complement matrix. isub = ',isub
!         do i = 1,ndofi
!            print '(100f10.6)',(schur((j-1)*ndofi + i),j = 1,ndofi)
!         end do
!         deallocate(schur)
!      end do
!*******************************************AUX
! Measure time spent in adaptivity
      call MPI_BARRIER(comm_all,ierr)
      timeaux1 = MPI_WTIME()
!*******************************************AUX
      call adaptivity_init(myid,comm_all,idpair,npair)

      print *, 'I am processor ',myid,': nproc = ',nproc, 'nsub = ',nsub
      call adaptivity_assign_pairs(npair,nproc,npair_locx)

      call adaptivity_solve_eigenvectors(subdomains,lsubdomains,sub2proc,lsub2proc,&
                                         indexsub,lindexsub,comm_all,npair_locx,npair)

      !print *,'nndf_coarse before update:'
      !print *,nndf_coarse
      call adaptivity_update_ndof(nndf_coarse,lnndf_coarse,nnodc,nedge,nface)
      !print *,'nndf_coarse after update:'
      !print *,nndf_coarse

      call adaptivity_finalize

!*******************************************AUX
! Measure time spent in adaptivity
      call MPI_BARRIER(comm_all,ierr)
      timeaux2 = MPI_WTIME()
      timeaux = timeaux2 - timeaux1
      if (myid.eq.0) then
         write(*,*) '***************************************'
         write(*,*) 'Time spent in adaptivity is ',timeaux,' s'
         write(*,*) '***************************************'
      end if
!*******************************************AUX

      ! prepare matrix C for corners, arithmetic averages on edges and adaptive on faces
      do isub_loc = 1,nsub_loc
         call dd_embed_cnodes(subdomains(isub_loc),nndf_coarse,lnndf_coarse)
         call dd_prepare_c(subdomains(isub_loc))
      end do
!
!      ! prepare augmented matrix for BDDC
!      do isub = 1,nsub
!         call dd_prepare_aug(myid,comm_self,isub)
!      end do
!
!      ! prepare coarse space basis functions for BDDC
!      do isub = 1,nsub
!         call dd_prepare_coarse(myid,isub)
!      end do

      ! print the output
      do isub_loc = 1,nsub_loc
         call dd_print_sub(subdomains(isub_loc))
      end do

   
      do isub_loc = 1,nsub_loc
         call dd_finalize(subdomains(isub_loc))
      end do
      deallocate(subdomains)
      deallocate(indexsub)
      deallocate(sub2proc)
      deallocate(nndf_coarse)

      ! close file with description of pairs
      if (myid.eq.0) then
         close(idpair)
      end if

      ! MPI finalization
!***************************************************************PARALLEL
      call MPI_FINALIZE(ierr)
!***************************************************************PARALLEL

end program
