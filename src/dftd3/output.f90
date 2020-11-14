! This file is part of s-dftd3.
! SPDX-Identifier: LGLP-3.0-or-later
!
! s-dftd3 is free software: you can redistribute it and/or modify it under
! the terms of the GNU Lesser General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! s-dftd3 is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU Lesser General Public License for more details.
!
! You should have received a copy of the GNU Lesser General Public License
! along with s-dftd3.  If not, see <https://www.gnu.org/licenses/>.

module dftd3_output
   use mctc_env, only : wp
   use mctc_io, only : structure_type
   use mctc_io_convert, only : autoaa, autokcal, autoev
   use mctc_io_math, only : matinv_3x3
   use dftd3_model, only : d3_model
   use dftd3_version, only : get_dftd3_version
   implicit none
   private

   public :: ascii_atomic_radii, ascii_atomic_references, ascii_system_properties
   public :: ascii_results
   public :: turbomole_gradient, turbomole_gradlatt
   public :: json_results


contains


subroutine ascii_atomic_radii(unit, mol, disp)

   !> Unit for output
   integer, intent(in) :: unit

   !> Molecular structure data
   class(structure_type), intent(in) :: mol

   !> Dispersion model
   class(d3_model), intent(in) :: disp

   integer :: isp

   write(unit, '(a,":")') "Atomic radii (in Angstrom)"
   write(unit, '(43("-"))')
   write(unit, '(a4,5x,*(1x,a10))') "Z", "R(cov)", "R(vdw)", "r4/r2"
   write(unit, '(43("-"))')
   do isp = 1, mol%nid
      write(unit, '(i4, 1x, a4, *(1x,f10.4))') &
         & mol%num(isp), mol%sym(isp), &
         & disp%rcov(isp)*autoaa, disp%rvdw(isp, isp)*autoaa/2, &
         & disp%r4r2(isp)*autoaa
   end do
   write(unit, '(43("-"))')

end subroutine ascii_atomic_radii


subroutine ascii_atomic_references(unit, mol, disp)

   !> Unit for output
   integer, intent(in) :: unit

   !> Molecular structure data
   class(structure_type), intent(in) :: mol

   !> Dispersion model
   class(d3_model), intent(in) :: disp

   integer :: isp, iref, mref

   mref = maxval(disp%ref)
   write(unit, '(a,":")') "Atomic reference systems (in atomic units)"
   write(unit, '(76("-"))')
   write(unit, '(a4, 5x)', advance='no') "Z"
   do iref = 1, 3
      write(unit, '(a4, 1x, a7, 1x, a9)', advance='no') "#", "CN", "C6(AA)"
   end do
   write(unit, '(a)')
   write(unit, '(76("-"))')
   do isp = 1, mol%nid
      write(unit, '(i4, 1x, a4)', advance='no') &
         & mol%num(isp), mol%sym(isp)
      do iref = 1, disp%ref(isp)
         write(unit, '(i4, 1x, f7.4, 1x, f9.4)', advance='no') &
            iref, disp%cn(iref, isp), disp%c6(iref, iref, isp, isp)
         if (iref == 3 .and. disp%ref(isp) > 3) then
            write(unit, '(/,9x)', advance='no')
         end if
      end do
      write(unit, '(a)')
   end do
   write(unit, '(76("-"))')

end subroutine ascii_atomic_references


subroutine ascii_system_properties(unit, mol, disp, cn, c6)

   !> Unit for output
   integer, intent(in) :: unit

   !> Molecular structure data
   class(structure_type), intent(in) :: mol

   !> Dispersion model
   class(d3_model), intent(in) :: disp

   !> Coordination numbers
   real(wp), intent(in) :: cn(:)

   !> Atomic dispersion coefficients
   real(wp), intent(in) :: c6(:, :)

   integer :: iat, isp

   write(unit, '(a,":")') "Dispersion properties (in atomic units)"
   write(unit, '(50("-"))')
   write(unit, '(a6,1x,a4,5x,*(1x,a10))') "#", "Z", "CN", "C6(AA)", "C8(AA)"
   write(unit, '(50("-"))')
   do iat = 1, mol%nat
      isp = mol%id(iat)
      write(unit, '(i6,1x,i4,1x,a4,*(1x,f10.4))') &
         & iat, mol%num(isp), mol%sym(isp), cn(iat), c6(iat, iat), &
         & c6(iat, iat)*3*disp%r4r2(isp)**2
   end do
   write(unit, '(50("-"))')

end subroutine ascii_system_properties


subroutine ascii_results(unit, mol, energy, gradient, sigma)

   !> Unit for output
   integer, intent(in) :: unit

   !> Molecular structure data
   class(structure_type), intent(in) :: mol

   real(wp), intent(in) :: energy
   real(wp), intent(in), optional :: gradient(:, :)
   real(wp), intent(in), optional :: sigma(:, :)

   integer :: iat, isp
   logical :: grad
   character(len=1), parameter :: comp(3) = ["x", "y", "z"]

   grad = present(gradient) .and. present(sigma)

   write(unit, '(a,":", t25, es20.13, 1x, a)') &
      & "Dispersion energy", energy, "Eh"
   write(unit, '(a)')
   if (grad) then
      write(unit, '(a,":", t25, es20.13, 1x, a)') &
         & "Gradient norm", norm2(gradient), "Eh/a0"
      write(unit, '(50("-"))')
      write(unit, '(a6,1x,a4,5x,*(1x,a10))') "#", "Z", "dE/dx", "dE/dy", "dE/dz"
      write(unit, '(50("-"))')
      do iat = 1, mol%nat
         isp = mol%id(iat)
         write(unit, '(i6,1x,i4,1x,a4,*(es11.3))') &
            & iat, mol%num(isp), mol%sym(isp), gradient(:, iat)
      end do
      write(unit, '(50("-"))')
      write(unit, '(a)')

      write(unit, '(a,":")') &
         & "Virial"
      write(unit, '(50("-"))')
      write(unit, '(a15,1x,*(1x,a10))') "component", "x", "y", "z"
      write(unit, '(50("-"))')
      do iat = 1, 3
         write(unit, '(2x,4x,1x,a4,1x,4x,*(es11.3))') &
            & comp(iat), sigma(:, iat)
      end do
      write(unit, '(50("-"))')
      write(unit, '(a)')
   end if

end subroutine ascii_results


subroutine turbomole_gradlatt(mol, fname, energy, sigma, stat)
   type(structure_type),intent(in) :: mol
   character(len=*),intent(in) :: fname
   real(wp),intent(in) :: energy
   real(wp),intent(in) :: sigma(3,3)
   integer, intent(out) :: stat
   character(len=:),allocatable :: line
   integer  :: i,j,icycle,line_number
   integer  :: err
   integer  :: igrad ! file handle
   logical  :: exist
   real(wp) :: escf
   real(wp) :: glat(3,3), inv_lat(3,3), gradlatt(3, 3)
   real(wp) :: dlat(3,3)
   stat = 0

   inv_lat = matinv_3x3(mol%lattice)

   do i = 1, 3
      do j = 1, 3
         gradlatt(i,j) = sigma(i,1)*inv_lat(j,1) &
            & + sigma(i,2)*inv_lat(j,2) &
            & + sigma(i,3)*inv_lat(j,3)
      enddo
   enddo

   icycle = 1
   i = 0
   escf = 0.0_wp

   inquire(file=fname,exist=exist)
   if (exist) then
      open(newunit=igrad,file=fname)
      read_file: do
         call getline(igrad,line,iostat=err)
         if (err.ne.0) exit read_file
         i=i+1
         if (index(line,'cycle') > 0) line_number = i
      enddo read_file
      if (line_number < 2) then
         stat = 1
         return
      endif

      rewind(igrad)
      skip_lines: do i = 1, line_number-1
         read(igrad,'(a)')
      enddo skip_lines
      call getline(igrad,line)
      read(line(10:17),*,iostat=err) icycle
      read(line(33:51),*,iostat=err) escf

      do i = 1, 3
         call getline(igrad,line)
         read(line,*,iostat=err) dlat(1,i),dlat(2,i),dlat(3,i)
      enddo
      if (any(abs(dlat-mol%lattice) > 1.0e-8_wp)) then
         stat = 1
         return
      endif
      do i = 1, 3
         call getline(igrad,line)
         read(line,*,iostat=err) glat(1,i),glat(2,i),glat(3,i)
      enddo
      do i = 1, 3
         backspace(igrad)
         backspace(igrad)
      enddo
      backspace(igrad)
   else
      open(newunit=igrad,file=fname)
      write(igrad,'("$gradlatt")')
   endif

   write(igrad,'(2x,"cycle =",1x,i6,4x,"SCF energy =",f18.11,3x,'//&
                   '"|dE/dlatt| =",f10.6)') &
      icycle, energy+escf, norm2(gradlatt+glat)
   do i = 1, 3
      write(igrad,'(3(F20.14,2x))') mol%lattice(1,i),mol%lattice(2,i),mol%lattice(3,i)
   enddo
   do i = 1, 3
      write(igrad,'(3D22.13)') gradlatt(1,i)+glat(1,i),gradlatt(2,i)+glat(2,i),gradlatt(3,i)+glat(3,i)
   enddo
   write(igrad,'("$end")')
   close(igrad)

end subroutine turbomole_gradlatt


subroutine turbomole_gradient(mol, fname, energy, gradient, stat)
   type(structure_type),intent(in) :: mol
   character(len=*),intent(in) :: fname
   real(wp),intent(in) :: energy
   real(wp),intent(in) :: gradient(:, :)
   integer, intent(out) :: stat
   character(len=:),allocatable :: line
   integer  :: i,icycle,line_number
   integer  :: err
   integer  :: igrad ! file handle
   logical  :: exist
   real(wp) :: escf
   real(wp),allocatable :: gscf(:,:)
   real(wp),allocatable :: xyz (:,:)
   allocate( gscf(3,mol%nat), source = 0.0_wp )
   stat = 0
   icycle = 1
   i = 0
   escf = 0.0_wp

   inquire(file=fname,exist=exist)
   if (exist) then
      open(newunit=igrad,file=fname)
      read_file: do
         call getline(igrad,line,iostat=err)
         if (err.ne.0) exit read_file
         i=i+1
         if (index(line,'cycle') > 0) line_number = i
      enddo read_file
      if (line_number < 2) then
         stat = 1
         return
      endif

      rewind(igrad)
      skip_lines: do i = 1, line_number-1
         read(igrad,'(a)')
      enddo skip_lines
      call getline(igrad,line)
      read(line(10:17),*,iostat=err) icycle
      read(line(33:51),*,iostat=err) escf

      allocate(xyz(3,mol%nat))
      do i = 1, mol%nat
         call getline(igrad,line)
         read(line,*,iostat=err) xyz(1,i),xyz(2,i),xyz(3,i)
      enddo
      if (any(abs(xyz-mol%xyz) > 1.0e-8_wp)) then
         stat = 1
         return
      endif
      do i = 1, mol%nat
         call getline(igrad,line)
         read(line,*,iostat=err) gscf(1,i),gscf(2,i),gscf(3,i)
      enddo
      do i = 1, mol%nat
         backspace(igrad)
         backspace(igrad)
      enddo
      backspace(igrad)
   else
      open(newunit=igrad,file=fname)
      write(igrad,'("$grad")')
   endif

   write(igrad,'(2x,"cycle =",1x,i6,4x,"SCF energy =",f18.11,3x,'//&
                   '"|dE/dxyz| =",f10.6)') &
      icycle, energy+escf, norm2(gradient+gscf)
   do i = 1, mol%nat
      write(igrad,'(3(F20.14,2x),4x,a2)') mol%xyz(1,i),mol%xyz(2,i),mol%xyz(3,i),mol%sym(i)
   enddo
   do i = 1, mol%nat
      write(igrad,'(3D22.13)') gradient(1,i)+gscf(1,i),gradient(2,i)+gscf(2,i),gradient(3,i)+gscf(3,i)
   enddo
   write(igrad,'("$end")')
   close(igrad)

end subroutine turbomole_gradient


!> reads a line from unit into an allocatable character
subroutine getline(unit,line,iostat)
   integer,intent(in) :: unit
   character(len=:),allocatable,intent(out) :: line
   integer,intent(out),optional :: iostat

   integer,parameter  :: buffersize=256
   character(len=buffersize) :: buffer
   integer :: size
   integer :: stat

   line = ''
   do
      read(unit,'(a)',advance='no',iostat=stat,size=size)  &
      &    buffer
      if (stat.gt.0) then
         if (present(iostat)) iostat=stat
         return ! an error occurred
      endif
      line = line // buffer(:size)
      if (stat.lt.0) then
         if (is_iostat_eor(stat)) stat = 0
         if (present(iostat)) iostat=stat
         return
      endif
   enddo

end subroutine getline


subroutine json_results(unit, indentation, energy, gradient, sigma, cn, c6)
   integer, intent(in) :: unit
   character(len=*), intent(in), optional :: indentation
   real(wp), intent(in), optional :: energy
   real(wp), intent(in), optional :: gradient(:, :)
   real(wp), intent(in), optional :: sigma(:, :)
   real(wp), intent(in), optional :: cn(:)
   real(wp), intent(in), optional :: c6(:, :)
   character(len=:), allocatable :: indent, version_string
   character(len=*), parameter :: jsonkey = "('""',a,'"":',1x)"
   real(wp), allocatable :: array(:)

   call get_dftd3_version(string=version_string)

   if (present(indentation)) then
      indent = indentation
   end if

   write(unit, '("{")', advance='no')
   if (allocated(indent)) write(unit, '(/,a)', advance='no') repeat(indent, 1)
   write(unit, jsonkey, advance='no') 'version'
   write(unit, '(1x,a)', advance='no') '"'//version_string//'"'
   if (present(energy)) then
      write(unit, '(",")', advance='no')
      if (allocated(indent)) write(unit, '(/,a)', advance='no') repeat(indent, 1)
      write(unit, jsonkey, advance='no') 'energy'
      write(unit, '(1x,es25.16)', advance='no') energy
   end if
   if (present(sigma)) then
      write(unit, '(",")', advance='no')
      if (allocated(indent)) write(unit, '(/,a)', advance='no') repeat(indent, 1)
      write(unit, jsonkey, advance='no') 'virial'
      array = reshape(sigma, [product(shape(sigma))])
      call write_json_array(unit, array, indent)
   end if
   if (present(gradient)) then
      write(unit, '(",")', advance='no')
      if (allocated(indent)) write(unit, '(/,a)', advance='no') repeat(indent, 1)
      write(unit, jsonkey, advance='no') 'gradient'
      array = reshape(gradient, [product(shape(gradient))])
      call write_json_array(unit, array, indent)
   end if
   if (present(cn)) then
      write(unit, '(",")', advance='no')
      if (allocated(indent)) write(unit, '(/,a)', advance='no') repeat(indent, 1)
      write(unit, jsonkey, advance='no') 'coordination numbers'
      call write_json_array(unit, cn, indent)
   end if
   if (present(c6)) then
      write(unit, '(",")', advance='no')
      if (allocated(indent)) write(unit, '(/,a)', advance='no') repeat(indent, 1)
      write(unit, jsonkey, advance='no') 'c6 coefficients'
      array = reshape(c6, [product(shape(c6))])
      call write_json_array(unit, array, indent)
   end if
   if (allocated(indent)) write(unit, '(/)', advance='no')
   write(unit, '("}")')

end subroutine json_results


subroutine write_json_array(unit, array, indent)
   integer, intent(in) :: unit
   real(wp), intent(in) :: array(:)
   character(len=:), allocatable, intent(in) :: indent
   integer :: i
   write(unit, '("[")', advance='no')
   do i = 1, size(array)
      if (allocated(indent)) write(unit, '(/,a)', advance='no') repeat(indent, 2)
      write(unit, '(1x,es25.16)', advance='no') array(i)
      if (i /= size(array)) write(unit, '(",")', advance='no')
   end do
   if (allocated(indent)) write(unit, '(/,a)', advance='no') repeat(indent, 1)
   write(unit, '("]")', advance='no')
end subroutine write_json_array


end module dftd3_output
