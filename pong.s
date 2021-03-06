# EE108B Lab 1
# Nipun Agarwala and Charles Guan
# This program implements a self-playing Pong game using the SPIM simulator
# and the provided Python script (for displaying MMIO)

# The display can draw squares of different colors on a 40x30 grid.
# (x,y): (0,0) is the top left, (39,29) is the bottom right
# To draw squares, use the following protocol:

# 1. Store a byte into the transmitter data register (address 0xffff000c)
# representing the x-coordinate of the square to draw. (number from 0 to 39)
# 2. Store a byte into the transmitter data register
# representing the y-coordinate of the square to draw. (number from 0 to 29)
# 3. Store a byte into the transmitter data register
# representing the color to make the square. (number from 0 to 7)
# The color format is 3-bit RGB, e.g., 0b100 is red, 0b010 is green,
# 0b110 is yellow, etc.

# Once the console has read three bytes successfully, it will display the
# square according to the three parameters supplied by your program.
# You must wait for the transmitter control register's ready bit
# to be set before writing a byte to the transmitter data register.
# Please see the appendix of the Patterson and Hennessy text on SPIM for
# a thorough explanation of the memory-mapped I/O mechanism in SPIM.
# This implementation is provided for you below in the "write_byte" function.
# Make sure you understand the implementation.

.text
.globl main

main:
# place constants on stack
    li    $t0, 39         # maximum x coordinate
    sw    $t0, 0($sp)
    li    $t0, 29         # maximum y coordinate
    sw    $t0, 4($sp)
    li    $t0, 0          # background color (black)
    sw    $t0, 8($sp)
    li    $t0, 0x02       # paddle color
    sw    $t0, 12($sp)
    li    $t0, 0x04       # ball color
    sw    $t0, 16($sp)
    li    $t0, 1          # ball height & width, paddle width
    sw    $t0, 20($sp)
    li    $t0, 6          # paddle height
    sw    $t0, 24($sp)
    li    $s0, 12         # Ball X coordinate
    li    $s1, 15         # Ball Y coordinate
    li    $s2, 0          # Counter
    li    $s3, 1          # X coordinate increment
    li    $s4, 1          # Y coordinate increment
    li    $s5, 1          # X direction
    li    $s6, 1          # Y direction
    li    $t1, 5          # Initialize counter
    li    $t2, 1

    jal   draw_paddle
    jal   draw_ball

game_loop:
    jal   draw_ball
    lw   $a2, 12($sp)
    addi  $s2, $s2, 1
    slt   $t2, $s2, $t1
    bne   $t2, $zero, game_loop
    jal   update_paddle
    jal   clear_ball
    jal   set_position
    j     game_loop

# This function draws the ball by first writing the updated X coordinate, then the Y coordinate 
# and finally the color.
draw_ball:
    addiu $sp, $sp, -4          # Push the stack frame
    sw    $ra, 0($sp)           # Save the $ra
    add   $a0, $s0, $zero       # Move the X coordinate value
    add   $a1, $s1, $zero       # Move the Y coordinate Value
    lw    $a2, 20($sp)          # Load the color
    jal   write_square 
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

# This function clears the ball by writing the current X coordinate, then the Y coordinate
# but colors it black
clear_ball:
    addiu $sp, $sp, -4          # Push the stack frame
    sw    $ra, 0($sp)           # Save the $ra
    add   $a0, $s0, $zero
    add   $a1, $s1, $zero
    add   $a2, $zero, $zero
    jal   write_square 
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

# This function sets the position of the ball by checking whether the ball is at the edges or
# is hitting a paddle. If it is, then it changes the direction of the ball respectively. 
# Otherwise, it increments the X and Y coordinate by 1.
set_position:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    jal   change_x_direction
    jal   change_y_direction

# This function updates the X and Y position of the ball in the registers after the
# conditions have been passed and resets the counter
change_position:
    add   $s0, $s0, $s5            # Increment the X and Y coordinates depending
    add   $s1, $s1, $s6            # on the direction of movement
    add   $s2, $zero, $zero        # Reset Counter
    lw    $ra, 0($sp)
    addiu  $sp, $sp, 4              # Push back stack frame
    jr    $ra

change_x_direction:
    lw    $t0, 4($sp)
    bne   $t0, $s0, test_x_next
    addi  $s5, $zero, -1
test_x_next: 
    addi  $t0, $zero, 1
    beq   $t0, $s0, hit_paddle
    bne   $s0, $zero, finish_x
    j     end_the_game
hit_paddle:
    addi  $s5, $zero, 1
finish_x:
    jr    $ra

change_y_direction:
    lw    $t0, 8($sp)
    bne   $t0, $s1, test_y_next
    addi  $s6, $zero, -1
test_y_next:
    bne   $s1, $zero, finish_y
    addi  $s6, $zero, 1
finish_y:
    jr    $ra

# send the exit signal to the display and make an exit syscall in SPIM
# this stops the Python Tk display and SPIM safely
end_the_game:
    li    $a0, 69 # 69 is 'E'
    jal   write_byte
    li    $v0, 10 # the exit syscall
    syscall

# function: draw_paddle
# draws a paddle centered at the ball's current y-coordinate.
# The width of the paddle is determined by a global var
# checks paddle bounds to ensure it does not write off-screen
# $a0 = x coordinate of paddle
# $a1 = initial y coordinate
# $a2 = color 
draw_paddle:
    addiu $sp, $sp, -32      # push stack frame
    sw    $ra, 28($sp)       # save $ra
    sw    $s0, 24($sp)       # make space for paddle height
    lw    $s0, 56($sp)       # i = paddle height (32 for this frame, + 24 from original)
    add   $a0, $zero, $zero  # x = 0 (left edge paddle)
    srl   $t0, $s0, 1        # center paddle on ball
    add   $a1, $s1, $t0
    j draw_paddle_for_cond
draw_paddle_loop:
    jal   write_square
    addi  $s0, $s0, -1       # i--
    addi  $a1, $a1, -1       # y-coordinate of paddle
draw_paddle_for_cond:
    slt   $t0, $zero, $s0    # 1 if i > 0
    bne   $t0, $zero, draw_paddle_loop
draw_paddle_exit:
    lw    $ra, 28($sp)       # load $ra
    lw    $s0, 24($sp)       # make space for paddle height
    addiu $sp, $sp, 32       # pop stack frame
    jr    $ra

# function: update_paddle
update_paddle:
    addiu $sp, $sp, -32
    sw    $ra, 28($sp)
    sw    $s0, 24($sp)       # make space for paddle height
    lw    $s0, 56($sp)       # i = paddle height (32 for this frame, + 24 from original)
    add   $a0, $zero, $zero  # x = 0 (left edge paddle)
    srl   $t0, $s0, 1        # center paddle on ball
    add   $a1, $s1, $t0
paddle_upper_bound:
    slti  $t0, $a1, 30       # 0 if y-coord too large
    beq   $t0, $zero, update_paddle_exit
paddle_lower_bound:
    addi  $t0, $s0, -1
    slt   $t0, $a1, $t0      # 1 if y-coord too small
    bne   $t0, $zero, update_paddle_exit
move_up_or_down:
    slt   $t0, $s6, $zero
    bne   $t0, $zero, move_up
move_down:                       # erase above and below current location
    addi  $a2, $zero, 0x02
    jal   write_square
    srl   $t0, $s0, 1        # center paddle on ball
    sub   $a1, $s1, $t0
    add   $a2, $zero, $zero
    jal   write_square
    j     update_paddle_exit
move_up:
    addi  $a1, $a1, 1
    add   $a2, $zero, $zero 
    jal   write_square
    sub   $a1, $a1, $s0
    addi  $a2, $zero, 0x02
    jal write_square
update_paddle_exit:
    lw    $ra, 28($sp)
    lw    $s0, 24($sp)       # make space for paddle height
    addiu $sp, $sp, 32       # pop stack frame
    jr    $ra

# function: write_square
# write the bytes in $a0, $a1, $a2 to the transmitter data register
# in sequence, corresponding in a drawn square at x=$a0,y=$a1,c=$a2

write_square:
    addiu $sp, $sp, -32      # push stack frame
    sw    $ra, 28($sp)       # save $ra
    sw    $a0, 20($sp)       # save a0 
    slt   $t0, $a1, $zero
    bne   $t0, $zero, exit_write
    slti  $t0, $a1, 30
    beq   $t0, $zero, exit_write
    jal   write_byte
    add   $a0, $a1, $zero    # store a1 to a0 to write byte
    jal   write_byte
    add   $a0, $a2, $zero    # store a2 to a0 to write byte
    jal   write_byte
exit_write:
    lw    $a0, 20($sp)       # restore a0
    lw    $ra, 28($sp)       # load $ra
    addiu $sp, $sp, 32
    jr    $ra                # pop stack frame

# function: write_byte
# write the byte in $a0 to the transmitter data register after polling
# the ready bit of the transmitter control register
# the transmitter control register is at address 0xffff0008
# the transmitter data register is at address 0xffff000c
# the "la" pseudoinstruction is very convenient for loading these addresses
# to a register in one line of MIPS assembly
# (it expands to two MIPS instructions)
write_byte:
    la    $t8, 0xffff0008
poll_for_ready:
    lw    $t9, 0($t8)
    andi  $t9, $t9, 1
    blez  $t9, poll_for_ready
    sw    $a0, 4($t8)
    jr    $ra
