# dmem[4] = 8
addi x1, x0, 4
addi x2, x0, 8
sw   x2, 0(x1)

# dmem[8] = 42
addi x3, x0, 8
addi x4, x0, 42
sw   x4, 0(x3)

addi x5, x0, 4
lw   x6, 0(x5)
lw   x7, 0(x6)
