# dmem[20] = 10
addi x1, x0, 20
addi x5, x0, 10
sw   x5, 0(x1)

lw   x2, 0(x1)
add  x3, x2, x2
add  x4, x3, x2
