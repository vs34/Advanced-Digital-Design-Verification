# jasper_formal.tcl
# JasperGold formal verification script

# Clear any previous setup
clear -all

# Analyze design files
analyze -sv09 \
    tb_if.sv \
    simple_cpu.v \
    sva_assertions.sv

# Elaborate the design
elaborate -top simple_cpu

# Set clock and reset
clock clk
reset -expression {!rst_n}

# Prove all assertions
prove -all

# Generate coverage report
report -file jasper_results.txt

# Summary of results
puts "\n=========================================="
puts "FORMAL VERIFICATION SUMMARY"
puts "=========================================="
puts "Total Assertions: [get_property_list -type assert -count]"
puts "Proven: [get_property_list -type assert -status proven -count]"
puts "Falsified: [get_property_list -type assert -status falsified -count]"
puts "Undetermined: [get_property_list -type assert -status undetermined -count]"
puts "==========================================\n"

# Save session
save_setup jasper_session.tcl
