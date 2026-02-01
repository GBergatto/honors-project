addi x1, x0, 0x111
sw   x1, 0(x0)

addi x2, x0, 0x222
sw   x2, 4(x0)

lw   x3, 0(x0)
lw   x4, 4(x0)
add  x5, x4, x0
