!+
! Subroutine type_ele (ele, type_zero_attrib, type_mat6, type_twiss, 
!                                                           type_control, ring)
!
! Subroutine to type out information on an element. 
! See also the subroutine type2_ele.
!
! Modules needed:
!   use bmad_struct
!   use bmad_interface
!
! Input:
!   ELE              -- Ele_struct: Element
!   TYPE_ZERO_ATTRIB -- Logical: If true then type all attributes even if the
!                          attribute value is 0.
!   TYPE_MAT6        -- Integer:
!                          TYPE_MAT6 = 0   => Do not type ELE%MAT6
!                          TYPE_MAT6 = 4   => Type 4X4 XY submatrix
!                          TYPE_MAT6 = 6   => Type full 6x6 matrix
!   TYPE_TWISS       -- Logical: If true then type the twiss parameters
!                          at the end of the element.
!   TYPE_CONTROL     -- Logical: If true then type control status.
!   RING             -- Ring_struct: Needed for control typeout.
!
!-


subroutine type_ele (ele, type_zero_attrib, type_mat6, type_twiss,  &
                                                       type_control, ring)

  use bmad_struct
  implicit none
  type (ele_struct)  ele
  type (ring_struct)  ring

  integer type_mat6, n_lines, i
  logical type_twiss, type_control, type_zero_attrib

  character*80 lines(50)

!

call type2_ele (ele, type_zero_attrib, type_mat6, type_twiss,  &
                                          type_control, ring, lines, n_lines)

  do i = 1, n_lines
    print '(1x, a)', trim(lines(i))
  enddo

end subroutine
