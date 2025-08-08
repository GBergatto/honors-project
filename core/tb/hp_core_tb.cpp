#include "Vhp_core.h"
#include "Vhp_core_hp_core.h"
#include "Vhp_core_regfile.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "common.hpp"
#include <cstdint>
#include <fstream>

int dtime = 0;

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    // 1) Prepare imem_init.hex
    {
        std::ofstream ofs("tb/firmware.hex");
        ofs << "00500093\n"  // addi x1, x0, 5
            << "00700113\n"  // addi x2, x0, 7
            << "002081B3\n"  // add  x3, x1, x2
            << "00119093\n"  // slli x1, x3, 1  ; x1 = x3 << 1
            ;
        ofs.close();
    }

    // 2) Instantiate core
    VerilatedContext* contextp = new VerilatedContext;
    VerilatedVcdC* tfp = new VerilatedVcdC;
    Vhp_core* dut = new Vhp_core;

    contextp->traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("vlt_dump.vcd");

    dut->clk = 0;
    dut->eval();
    tfp->dump(dtime++);

    // 3) Run
    for (int i = 0; i < 4; i++) {
        dut->clk = 1;
        dut->eval();
        tfp->dump(dtime++);

        dut->clk = 0;
        dut->eval();
        tfp->dump(dtime++);
    }

    // the output of the ALU is written to the register file
    // on the next positive clock edge
    dut->clk = 1;
    dut->eval();
    tfp->dump(dtime++);

    // 4) Check register x1
    uint32_t x1 = dut->hp_core->regfile_i->get_reg(1);
    check("(5 + 7) << 1", x1, 24);

    // simulate one extra cycle for a nicer waveform
    dut->clk = 0;
    dut->eval();
    tfp->dump(dtime++);
    dut->clk = 1;
    dut->eval();
    tfp->dump(dtime++);

    tfp->close();

    delete dut;
    return failures ? 1 : 0;
}

