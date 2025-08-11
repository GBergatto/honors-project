// tb/core_tb_mem.cpp
#include "Vhp_core.h"
#include "Vhp_core_hp_core.h"
#include "Vhp_core_regfile.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "common.hpp"
#include <cstdint>
#include <fstream>
#include <cstdlib>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    // 1) Prepare firmware
    {
        std::ofstream ofs("tb/firmware.hex");
        ofs << "00500093\n" // addi x1, x0, 5
            << "00700113\n" // addi x2, x0, 7
            << "002081B3\n" // add  x3, x1, x2
            << "00302023\n" // sw   x3, 0(x0)
            << "00002203\n" // lw   x4, 0(x0)
            << "00121293\n"; // slli x5, x4, 1;
    }

    // 2) Instantiate core + tracing
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    VerilatedVcdC* tfp = new VerilatedVcdC;

    Vhp_core* dut = new Vhp_core{contextp};

    contextp->traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("vlt_dump.vcd");

    // 3) Initial conditions
    int time = 0;
    dut->clk = 0;
    dut->eval();
    tfp->dump(time++);

    // 4) Run for instructions + 1 extra cycle for final writeback
    const int n_instr = 6;
    for (int cycle = 0; cycle < n_instr + 1; ++cycle) {
        // rising edge
        dut->clk = 1;
        dut->eval();
        tfp->dump(time++);

        // falling edge
        dut->clk = 0;
        dut->eval();
        tfp->dump(time++);
    }

    // 5) Read back registers via Verilator accessor
    uint32_t x4 = dut->hp_core->regfile_i->get_reg(4);
    check("x4 == 12 (loaded from memory)", x4, 12u);

    uint32_t x5 = dut->hp_core->regfile_i->get_reg(5);
    check("x5 == 24 (x4 << 1)", x5, 24u);

    // 6) Finalize
    tfp->flush();
    tfp->close();
    delete tfp;
    delete dut;
    delete contextp;
}

