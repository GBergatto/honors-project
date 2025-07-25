#include "Vhp_core.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "verilated_cov.h"

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);

    VerilatedContext* contextp = new VerilatedContext;
    Vhp_core* top = new Vhp_core{contextp};
    VerilatedVcdC* tfp = new VerilatedVcdC;

    contextp->traceEverOn(true);
    top->trace(tfp, 99);
    tfp->open("vlt_dump.vcd");

    top->reset = 1;
    top->clk = 0;

    for (int i = 0; i < 2; ++i) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(i);
    }

    top->reset = 0;

    for (int i = 2; i < 40; ++i) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(i);
    }

    tfp->close();
    VerilatedCov::write("logs/coverage.dat");

    delete tfp;
    delete top;
    delete contextp;
    return 0;
}

