#include "Vhp_core.h"
#include "Vhp_core_hp_core.h"
#include "Vhp_core_regfile.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "common.hpp"

#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <yaml-cpp/yaml.h>  // requires yaml-cpp

namespace fs = std::filesystem;

// Convert firmware from binary into HEX
int bin_to_hex(const fs::path& bin_file, const fs::path& hex_file) {
    std::ifstream ifs(bin_file, std::ios::binary);
    if (!ifs) throw std::runtime_error("Cannot open " + bin_file.string());

    std::ofstream ofs(hex_file);
    if (!ofs) throw std::runtime_error("Cannot open " + hex_file.string());

    int n_instructions = 0;
    uint8_t buf[4];
    while (ifs.read(reinterpret_cast<char*>(buf), 4) || ifs.gcount() > 0) {
        // pad with zeros if less than 4 bytes at the end
        uint32_t word = 0;
        for (size_t i = 0; i < ifs.gcount(); ++i) {
            word |= buf[i] << (8 * i); // little-endian
        }
        ofs << std::hex << std::setw(8) << std::setfill('0') << word << "\n";
        n_instructions++;
    }
    return n_instructions;
}

// Assemble RISC-V assembly file into firmaware.hex
int assemble_to_hex(const fs::path& asm_file, const fs::path& hex_file) {
    std::string elf_file = asm_file.stem().string() + ".elf";
    std::string bin_file = asm_file.stem().string() + ".bin";

    // Assemble
    if (std::system(("riscv32-unknown-elf-as -march=rv32i -mabi=ilp32 " 
                     + asm_file.string() + " -o " + elf_file).c_str()) != 0)
        throw std::runtime_error("Assembler failed");

    // Objcopy to raw binary
    if (std::system(("riscv32-unknown-elf-objcopy -O binary " + elf_file
                    + " " + bin_file).c_str()) != 0)
        throw std::runtime_error("Objcopy failed");

    // Convert binary to hex
    int n_instructions = bin_to_hex(bin_file, hex_file);

    // Cleanup
    fs::remove(elf_file);
    fs::remove(bin_file);

    return n_instructions;
}

void run_test(const fs::path& asm_file, const fs::path& yaml_file) {
    std::cout << "\n[TEST] " << asm_file.stem().string() << std::endl;

    // 1) assemble program
    fs::path hex_file = "tb/roms/firmware.hex";
    int n_instructions = assemble_to_hex(asm_file, hex_file);

    // 2) load expected register values from YAML file
    YAML::Node exp = YAML::LoadFile(yaml_file.string());
    std::map<int, uint32_t> expected;
    for (auto it = exp.begin(); it != exp.end(); ++it) {
        std::string reg = it->first.as<std::string>();
        int idx = std::stoi(reg.substr(1));
        uint32_t val = it->second.as<uint32_t>();
        expected[idx] = val;
    }

    // 3) set up simulation
    VerilatedContext* contextp = new VerilatedContext;
    VerilatedVcdC* tfp = new VerilatedVcdC;
    Vhp_core* dut = new Vhp_core{contextp};

    contextp->traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open(("logs/waves/" + asm_file.stem().string() + ".vcd").c_str());

    int time = 0;
    dut->clk = 0;
    dut->rst = 1;
    dut->eval();
    tfp->dump(time++);

    // reset
    for (int i = 0; i < 2; i++) {
        dut->clk = 1; dut->eval(); tfp->dump(time++);
        dut->clk = 0; dut->eval(); tfp->dump(time++);
    }
    dut->rst = 0;

    // 4) run
    for (int cycle = 0; cycle < 5 * n_instructions; ++cycle) {
        dut->clk = 1; dut->eval(); tfp->dump(time++);
        dut->clk = 0; dut->eval(); tfp->dump(time++);
    }

    // 5) check registers
    for (auto& [idx, exp_val] : expected) {
        uint32_t got = dut->hp_core->regfile_i->get_reg(idx);
        check("x" + std::to_string(idx), got, exp_val);
    }

    // cleanup
    tfp->flush();
    tfp->close();
    delete tfp;
    delete dut;
    delete contextp;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    for (auto& entry : fs::directory_iterator("tb/roms")) {
        if (entry.path().extension() == ".s") {
            fs::path asm_file = entry.path();
            fs::path yaml_file = asm_file;
            yaml_file.replace_extension(".yaml");
            if (fs::exists(yaml_file)) {
                run_test(asm_file, yaml_file);
            } else {
                std::cerr << "Warning: no YAML for " << asm_file << "\n";
            }
        }
    }
    return 0;
}

