## Placeholder constraints for xc7s6-1ftgb196.
## Fill in board-specific PACKAGE_PIN values before implementation.

create_clock -period 10.000 -name clk [get_ports clk]

# set_property PACKAGE_PIN <PIN> [get_ports clk]
# set_property IOSTANDARD LVCMOS33 [get_ports clk]

# set_property PACKAGE_PIN <PIN> [get_ports rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# set_property PACKAGE_PIN <PIN> [get_ports bit_valid]
# set_property IOSTANDARD LVCMOS33 [get_ports bit_valid]

# set_property PACKAGE_PIN <PIN> [get_ports {bits_in[0]}]
# set_property PACKAGE_PIN <PIN> [get_ports {bits_in[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {bits_in[*]}]

# set_property IOSTANDARD LVCMOS33 [get_ports {i_out[*]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {q_out[*]}]
# set_property IOSTANDARD LVCMOS33 [get_ports sym_valid]
