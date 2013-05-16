######################################################################
# Snake clone                                                        #
#                                                                    #
# Written by Owen Rodley                                             #
#                                                                    #
# Portions of this code are taken from (or are modified versions of) #
# sections of the Multitasking Kernel Implmentation Job 3, and are   #
# Copyright (c) 2002, The University of Waikato                      #
#                                                                    #
######################################################################
# Stuff to do:
#  Use left and right arrow keys
#   (Maybe, it uses some weird 3-char escape code or something)
#  Display score
#  TESTING!!!

	.equ	sp2_trn,	0x71000
	.equ	sp2_rcv,	0x71001
	.equ	sp2_stat,	0x71003

.bss
snake_body:
# Space for storing the pieces of the snake's body.
# Each word is a co-ordinate; the 16 MSB are the x co-ordinate,
# and the 16 LSB the y co-ordinate
	.space 100
snake_end:	# Save the end, for tracking wraparound

.data
# Strings made of ANSI escape codes for manipulating the serial terminal
clear_screen:	.asciiz "\033[2J\033[H\033[?25l"
press_enter:	.asciiz	"\007\033[12;29H Press Enter to play "
you_lose:	.asciiz	"\007\033[12;34H You lose "
pos:		.asciiz	"\033[xx;xxH"
l_and_r_walls:	.asciiz "\n\r#\033[79C#"
# Game "graphics"
snake_char:	.asciiz "O"
pellet_char:	.asciiz "@"
dead_char:	.asciiz "x"
space:		.asciiz " "

# Stuff for the random number generator
next:	.word	0
A:	.word	16807
M:	.word	2147483647
q:	.word	127773
r:	.word	2836

.text
.global main
main:
	# Set up inital pointers into snake_body
	# $13 stores the location of the head of the snake and $12 the tail
	la	$12, snake_body
	addui	$13, $12, 1

	lhi	$1,     0x0028		# Store (40, 12) in the tail...
	ori	$1, $1, 0x000C
	sw	$1, 0($12)
	
	lhi	$1,     0x0029		# ...and (41, 12) in the head
	ori	$1, $1, 0x000C
	sw	$1, 0($13)

	# $11 stores the direction of the snake.
	# Bits 1-2 = 00 for straight, 01 for down,  10 for up
	# Bits 3-4 = 00 for straight, 01 for right, 10 for left
	addui	$11, $0, 4		# Initial value = 4 = 0b0100 = right


	la	$1, clear_screen	# Clear the screen
	sw	$1, 0($sp)
	jal	print

	la	$1, press_enter		# Prompt for enter
	sw	$1, 0($sp)
	jal	print

wait_for_enter:
	jal	getkey
	seqi	$1, $1, 13
	beqz	$1, wait_for_enter

	la	$1, clear_screen	# Clear the screen
	sw	$1, 0($sp)
	jal	print

	jal	draw_walls		# Draw the walls

	# Display the initial two segments of the snake
	subui	$sp, $sp, 2

	la	$1, snake_char
	sw	$1, 1($sp)

	lw	$1, 0($13)
	sw	$1, 0($sp)
	jal	print_at
	lw	$1, 0($12)
	sw	$1, 0($sp)
	jal	print_at


	jal	generate_pellet		# Generate the first pellet...

	la	$1, pellet_char
	sw	$1, 1($sp)

	sw	$10, 0($sp)
	jal	print_at		# ...and print it

	addui	$sp, $sp, 2

gameloop:
	jal	move_head
	bnez	$1, collect_pellet	# Check if we hit a pellet

	jal	move_tail
	j	after_pellet

collect_pellet:
	jal	generate_pellet

	la	$1, pellet_char
	sw	$1, 1($sp)

	sw	$10, 0($sp)
	jal	print_at		# Print the new pellet

after_pellet:
	addui	$1, $0, 2
	sw	$1, 0($sp)
	jal	wait_n

	jal	getkey
	jal	handle_key

	jal check_lose
	bnez	$1, lose

	j gameloop

lose:
	subui	$sp, $sp, 1		# Replace head with "x"
	la	$1, dead_char
	sw	$1, 1($sp)

	lw	$1, 0($13)
	sw	$1, 0($sp)
	jal	print_at
	addui	$sp, $sp, 1

	la	$1, you_lose
	sw	$1, 0($sp)
	jal	print

	addui	$1, $0, 32
	sw	$1, 0($sp)
	jal	wait_n

	j main


#####################################################################
# Subroutines

# Print a null-terminated string to the serial port
print:	
	subui	$sp, $sp, 1
	sw	$2, 0($sp)

	lw	$1, 1($sp)		# the pointer to the string
poll:	
	lw	$2, sp2_stat($0)	# read the status from the port
	andi	$2, $2, 2		# mask off bit 0, tdr
	beqz	$2, poll

	lw	$2, 0($1)		# get the next character in the string
	beqz	$2, print_done		# break if end of string

	sw	$2, sp2_trn($0)		# send the character to the console
	addi	$1, $1, 1		# increment the pointer
	j	poll			# print next character

print_done:
	lw	$2, 0($sp)
	addui	$sp, $sp, 1
	jr	$ra

# Draw the walls around the boundary of the screen
draw_walls:
	subui	$sp, $sp, 3
	sw	$3, 3($sp)
	sw	$2, 2($sp)
	sw	$ra, 1($sp)

	addui	$1, $0, 80		# 80 chars are going to be sent
	addui	$2, $0, '#'		# Use '#' to represent a wall
	jal	poll2

	la	$1, l_and_r_walls
	sw	$1, 0($sp)

	addui	$2, $0, 22
next_line:
	jal	print
	subui	$2, $2, 1
	bnez	$2, next_line

	addui	$1, $0, 1
	addui	$2, $0, '\n'
	jal	poll2
	addui	$1, $0, 1
	addui	$2, $0, '\r'
	jal	poll2

	addui	$1, $0, 80
	addui	$2, $0, '#'
	jal	poll2			# Draw wall at bottom of screen

	lw	$3, 3($sp)
	lw	$2, 2($sp)
	lw	$ra, 1($sp)
	jr	$ra

poll2:
	lw	$3, sp2_stat($0)
	andi	$3, $3, 2
	beqz	$3, poll2

	sw	$2, sp2_trn($0)
	subui	$1, $1, 1
	bnez	$1, poll2		# Loop when n chars been sent

	jr	$ra

# Set the cursor position
setpos:
	subui	$sp, $sp, 5
	sw	$2, 1($sp)
	sw	$3, 2($sp)
	sw	$4, 3($sp)
	sw	$ra, 4($sp)		# store return address on stack

	lw	$3, 5($sp)
	lw	$4, 6($sp)
		
	la	$2, pos
	
	remi	$1, $3, 10		# get 1s digit of X pos
	addi	$1, $1, '0'
	sw	$1, 6($2)	

	divi	$1, $3, 10		# get 10s digit of X pos
	addi	$1, $1, '0'
	sw	$1, 5($2)	

	remi	$1, $4, 10		# get 1s digit of Y pos
	addi	$1, $1, '0'
	sw	$1, 3($2)	

	divi	$1, $4, 10		# get 10s digit of Y pos
	addi	$1, $1, '0'
	sw	$1, 2($2)	
	

	sw	$2, 0($sp)
	jal	print			# print escape sequence
	

	lw	$2, 1($sp)
	lw	$3, 2($sp)
	lw	$4, 3($sp)
	lw	$ra, 4($sp)		# get return address from stack
	addui	$sp, $sp, 5
	jr	$ra

# Print a string at a coordinate stored in two halves of a word
print_at:
	subui	$sp, $sp, 5
	sw	$2,  3($sp)
	sw	$ra, 2($sp)
	lw	$1, 5($sp)
	lw	$2, 6($sp)

	srli	$1, $1, 16
	sw	$1, 0($sp)

	lw	$1, 5($sp)
	andi	$1, $1, 0xFFFF
	sw	$1, 1($sp)

	jal	setpos

	sw	$2, 0($sp)
	jal	print

	lw	$ra, 2($sp)
	lw	$2,  3($sp)
	addui	$sp, $sp, 5
	jr	$ra

# Get a keypress from the serial port and return it, returning 0 for no key
getkey:
	subui	$sp, $sp, 1
	sw	$2, 0($sp)

	add	$1, $0, $0		# return 0 for no key pressed
	lw	$2, sp2_stat($0)

	andi	$2, $2, 0x1		# has a key been pressed?
	beqz	$2, no_key

	lw	$1, sp2_rcv($0)		# if so, get it

no_key:
	lw	$2, 0($sp)
	addui	$sp, $sp, 1
	jr	$ra

# Move the head of the snake forward one square, and return 1 if the pellet
# is on the square we moved to
move_head:
	subui	$sp, $sp, 4
	sw	$2,  4($sp)
	sw	$3,  3($sp)
	sw	$ra, 2($sp)

	lw	$1, 0($13)
	srli	$2, $1, 16
	andi	$1, $1, 0xFFFF

horizontal:
	srli	$3, $11, 2
	beqz	$3, vertical

	andi	$3, $3, 1
	beqz	$3, left
right:
	addui	$2, $2, 1
	j	vertical
left:
	subui	$2, $2, 1

vertical:
	andi	$3, $11, 3
	beqz	$3, set_coord

	andi	$3, $3, 1
	beqz	$3, up
down:
	addui	$1, $1, 1
	j	set_coord
up:
	subui	$1, $1, 1

set_coord:
	slli	$3, $2, 16
	or	$3, $3, $1

	addui	$13, $13, 1

	la	$1, snake_end
	seq	$1, $1, $13		# Check if we're at the end of the array
	beqz	$1, store_head

	subui	$13, $13, 100

store_head:
	sw	$3, 0($13)

	la	$1, snake_char
	sw	$1, 1($sp)
	sw	$3, 0($sp)
	jal	print_at

	seq	$2, $3, $10		# Check if we've hit the pellet
	bnez	$2, return_one

	addui	$1, $0, 0
	j	done

return_one:
	addui	$1, $0, 1

done:
	lw	$ra, 2($sp)
	lw	$3,  3($sp)
	lw	$2,  4($sp)
	addui	$sp, $sp, 4
	jr	$ra

# Move the tail of the snake forward one square
move_tail:
	subui	$sp, $sp, 2
	sw	$ra, 2($sp)

	la	$1, space
	sw	$1, 1($sp)
	lw	$1, 0($12)
	sw	$1, 0($sp)
	jal	print_at

	addui	$12, $12, 1

	la	$1, snake_end
	seq	$1, $1, $12		# Check if we're at the end of the array
	beqz	$1, store_tail

	subui	$12, $12, 100

store_tail:
	lw	$ra, 2($sp)
	addui	$sp, $sp, 2
	jr	$ra

# Wait for 15000 loop iterations
wait:	
	addui	$1, $0, 15000
waitloop:
	subi	$1, $1, 1
	bnez	$1, waitloop

	jr	$ra

# Call wait n times
wait_n:
	subui	$sp, $sp, 2
	sw	$ra, 0($sp)
	sw	$2,  1($sp)
	lw	$2,  2($sp)

wait_n_loop:
	beqz	$2, end_wait_n
	jal	wait
	subui	$2, $2, 1
	j	wait_n_loop

end_wait_n:
	lw	$2,  1($sp)
	lw	$ra, 0($sp)
	addui	$sp, $sp, 2

	jr	$ra


# Check if the edge of the screen has been hit
check_lose:
	subui	$sp, $sp, 1
	sw	$2, 1($sp)
	sw	$3, 2($sp)

	lw	$2, 0($13)
	# Check if we've hit the left...
	srli	$1, $2, 16
	seqi	$1, $1, 1
	bnez	$1, collision
	# ...or right edge of the screen
	srli	$1, $2, 16
	sgei	$1, $1, 80
	bnez	$1, collision

	# Check if we've hit the top
	andi	$1, $2, 0xFFFF
	seqi	$1, $1, 1
	bnez	$1, collision
	# ...or bottom of the screen
	andi	$1, $2, 0xFFFF
	sgei	$1, $1, 24
	bnez	$1, collision


	# Check for self-collision
	add	$1, $0, $12		# Start from the tail pointer

loop:
	seq	$3, $1, $13		# Check if pointer has reached head
	bnez	$3, no_collision	# If so, we're done searching

	lw	$3, 0($1)
	seq	$3, $3, $2		# Check if co-ords are the same
	bnez	$3, collision		# If so, we've collided

	addui	$1, $1, 1		# Increment pointer

	la	$3, snake_end		# Check for wraparound
	seq	$3, $3, $1
	beqz	$3, loop

	subui	$1, $1, 100

	j	loop

no_collision:
	addui	$1, $0, 0
	j	end

collision:
	addui	$1, $0, 1

end:
	lw	$2, 1($sp)
	lw	$3, 2($sp)
	addui	$sp, $sp, 1
	jr	$ra
	
# Change the way the snake is moving based on what key's been hit
handle_key:
	subui	$sp, $sp, 1
	sw	$2, 0($sp)

	beqz	$1, return		# No key; do nothing

	seqi	$2, $1, 'w'		# Go up for 'w'
	beqz	$2, L1

	addui	$11, $0, 2
	j	return
L1:
	seqi	$2, $1, 'a'		# Go left for 'a'
	beqz	$2, L2

	addui	$11, $0, 8
	j	return
L2:
	seqi	$2, $1, 's'		# Go down for 's'
	beqz	$2, L3

	addui	$11, $0, 1
	j	return
L3:
	seqi	$2, $1, 'd'		# Go right for 'd'
	beqz	$2, return

	addui	$11, $0, 4
return:
	addui	$sp, $sp, 1
	lw	$2, 0($sp)
	jr	$ra

# Generate a random number between 0 and the argument
random:
	subui	$sp, $sp, 4
	sw	$2, 0($sp)
	sw	$3, 1($sp)
	sw	$4, 2($sp)
	sw	$5, 3($sp)
	
	# if next == 0 then seed
	lw	$2, next($0)
	bnez	$2, pick_next

	# fetch a random seed from the CPU cycle count (a special
	# purpose register)
	movsg	$2, $ccount

	# Limit the seed to a (positive) 16 bit value
	andi	$2, $2, 0xffff
	
pick_next:
	# The random number is picked using the following formula	
	# next = A * (next % q) - r * (next / q)
	
	lw	$3, q($0)

	rem	$4, $2, $3
	div	$5, $2, $3
	lw	$2, r($0)
	mult	$5, $5, $2		# $5 = r * (next / q)

	lw	$2, A($0)
	mult	$4, $4, $2		# $4 = A * (next % q)

	sub	$4, $4, $5

	slt	$1, $4, $0
	beqz	$1, rand_return

	lw	$2, M($0)
	add	$4, $4, $2

rand_return:
	sw	$4, next($0)
		
	lw	$2, 4($sp)		# get our argument (the max number)
	rem	$1, $4, $2		# limit the number to the range we want

	lw	$2, 0($sp)
	lw	$3, 1($sp)
	lw	$4, 2($sp)
	lw	$5, 3($sp)
	
	addui	$sp, $sp, 4
	jr	$ra

# Generate a pellet somewhere on the screen
generate_pellet:
	subui	$sp, $sp, 3
	sw	$ra, 3($sp)
	sw	$2,  2($sp)
	sw	$3,  1($sp)

	# x co-ordinate
	addui	$1, $0, 77		# Random number from 0-77
	sw	$1, 0($sp)
	jal	random
	addui	$1, $1, 2		# 2-79
	slli	$10, $1, 16

	# y co-ordinate
	addui	$1, $0, 22		# Random number from 0-21
	sw	$1, 0($sp)
	jal	random
	addui	$1, $1, 2		# 2-23
	or	$10, $10, $1

	# Check if the pellet is on the snake
	add	$2, $0, $12		# Start from the tail pointer

loop2:
	seq	$3, $2, $13		# Check if pointer has reached head
	bnez	$3, g_p_end		# If so, we're done searching

	lw	$3, 0($2)
	seq	$3, $3, $10		# Check if co-ords are the same
	bnez	$3, generate_pellet	# If so, pellet is on snake

	addui	$2, $2, 1		# Increment pointer

	la	$3, snake_end		# Check for wraparound
	seq	$3, $3, $2
	beqz	$3, loop2

	subui	$2, $2, 100

	j	loop2

g_p_end:
	lw	$3,  1($sp)
	lw	$2,  2($sp)
	lw	$ra, 3($sp)
	addui	$sp, $sp, 1
	jr	$ra
#
#####################################################################
