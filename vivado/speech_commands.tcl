
################################################################
# This is a generated script based on design: speech_commands
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2021.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source speech_commands_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# adcs747x_to_axism, hann_window_to_axism, top_artya7100t

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7a100tcsg324-1
   set_property BOARD_PART digilentinc.com:arty-a7-100:part0:1.0 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name speech_commands

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:axi_intc:4.1\
xilinx.com:ip:axi_quad_spi:3.2\
xilinx.com:ip:axi_timer:2.0\
xilinx.com:ip:axi_uartlite:2.0\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:mdm:3.2\
xilinx.com:ip:microblaze:11.0\
xilinx.com:ip:mig_7series:4.2\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:smartconnect:1.0\
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:axi_gpio:2.0\
xilinx.com:ip:floating_point:7.1\
xilinx.com:ip:axis_subset_converter:1.1\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:lmb_bram_if_cntlr:4.0\
xilinx.com:ip:lmb_v10:3.0\
xilinx.com:ip:blk_mem_gen:8.4\
xilinx.com:ip:axis_broadcaster:1.1\
xilinx.com:ip:xfft:9.1\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
adcs747x_to_axism\
hann_window_to_axism\
top_artya7100t\
"

   set list_mods_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2021 -severity "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_gid_msg -ssname BD::TCL -id 2022 -severity "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}


##################################################################
# MIG PRJ FILE TCL PROCs
##################################################################

proc write_mig_file_speech_commands_mig_7series_0_1 { str_mig_prj_filepath } {

   file mkdir [ file dirname "$str_mig_prj_filepath" ]
   set mig_prj_file [open $str_mig_prj_filepath  w+]

   puts $mig_prj_file {﻿<?xml version="1.0" encoding="UTF-8" standalone="no" ?>}
   puts $mig_prj_file {<Project NoOfControllers="1">}
   puts $mig_prj_file {  }
   puts $mig_prj_file {<!-- IMPORTANT: This is an internal file that has been generated by the MIG software. Any direct editing or changes made to this file may result in unpredictable behavior or data corruption. It is strongly advised that users do not edit the contents of this file. Re-run the MIG GUI with the required settings if any of the options provided below need to be altered. -->}
   puts $mig_prj_file {  <ModuleName>speech_commands_mig_7series_0_1</ModuleName>}
   puts $mig_prj_file {  <dci_inouts_inputs>1</dci_inouts_inputs>}
   puts $mig_prj_file {  <dci_inputs>1</dci_inputs>}
   puts $mig_prj_file {  <Debug_En>OFF</Debug_En>}
   puts $mig_prj_file {  <DataDepth_En>1024</DataDepth_En>}
   puts $mig_prj_file {  <LowPower_En>ON</LowPower_En>}
   puts $mig_prj_file {  <XADC_En>Enabled</XADC_En>}
   puts $mig_prj_file {  <TargetFPGA>xc7a100t-csg324/-1</TargetFPGA>}
   puts $mig_prj_file {  <Version>4.2</Version>}
   puts $mig_prj_file {  <SystemClock>No Buffer</SystemClock>}
   puts $mig_prj_file {  <ReferenceClock>No Buffer</ReferenceClock>}
   puts $mig_prj_file {  <SysResetPolarity>ACTIVE LOW</SysResetPolarity>}
   puts $mig_prj_file {  <BankSelectionFlag>FALSE</BankSelectionFlag>}
   puts $mig_prj_file {  <InternalVref>1</InternalVref>}
   puts $mig_prj_file {  <dci_hr_inouts_inputs>50 Ohms</dci_hr_inouts_inputs>}
   puts $mig_prj_file {  <dci_cascade>0</dci_cascade>}
   puts $mig_prj_file {  <Controller number="0">}
   puts $mig_prj_file {    <MemoryDevice>DDR3_SDRAM/Components/MT41K128M16XX-15E</MemoryDevice>}
   puts $mig_prj_file {    <TimePeriod>3077</TimePeriod>}
   puts $mig_prj_file {    <VccAuxIO>1.8V</VccAuxIO>}
   puts $mig_prj_file {    <PHYRatio>4:1</PHYRatio>}
   puts $mig_prj_file {    <InputClkFreq>99.997</InputClkFreq>}
   puts $mig_prj_file {    <UIExtraClocks>0</UIExtraClocks>}
   puts $mig_prj_file {    <MMCM_VCO>649</MMCM_VCO>}
   puts $mig_prj_file {    <MMCMClkOut0> 1.000</MMCMClkOut0>}
   puts $mig_prj_file {    <MMCMClkOut1>1</MMCMClkOut1>}
   puts $mig_prj_file {    <MMCMClkOut2>1</MMCMClkOut2>}
   puts $mig_prj_file {    <MMCMClkOut3>1</MMCMClkOut3>}
   puts $mig_prj_file {    <MMCMClkOut4>1</MMCMClkOut4>}
   puts $mig_prj_file {    <DataWidth>16</DataWidth>}
   puts $mig_prj_file {    <DeepMemory>1</DeepMemory>}
   puts $mig_prj_file {    <DataMask>1</DataMask>}
   puts $mig_prj_file {    <ECC>Disabled</ECC>}
   puts $mig_prj_file {    <Ordering>Normal</Ordering>}
   puts $mig_prj_file {    <BankMachineCnt>4</BankMachineCnt>}
   puts $mig_prj_file {    <CustomPart>FALSE</CustomPart>}
   puts $mig_prj_file {    <NewPartName/>}
   puts $mig_prj_file {    <RowAddress>14</RowAddress>}
   puts $mig_prj_file {    <ColAddress>10</ColAddress>}
   puts $mig_prj_file {    <BankAddress>3</BankAddress>}
   puts $mig_prj_file {    <MemoryVoltage>1.35V</MemoryVoltage>}
   puts $mig_prj_file {    <C0_MEM_SIZE>268435456</C0_MEM_SIZE>}
   puts $mig_prj_file {    <UserMemoryAddressMap>BANK_ROW_COLUMN</UserMemoryAddressMap>}
   puts $mig_prj_file {    <PinSelection>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="R2" SLEW="" VCCAUX_IO="" name="ddr3_addr[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="R6" SLEW="" VCCAUX_IO="" name="ddr3_addr[10]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="U6" SLEW="" VCCAUX_IO="" name="ddr3_addr[11]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="T6" SLEW="" VCCAUX_IO="" name="ddr3_addr[12]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="T8" SLEW="" VCCAUX_IO="" name="ddr3_addr[13]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="M6" SLEW="" VCCAUX_IO="" name="ddr3_addr[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="N4" SLEW="" VCCAUX_IO="" name="ddr3_addr[2]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="T1" SLEW="" VCCAUX_IO="" name="ddr3_addr[3]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="N6" SLEW="" VCCAUX_IO="" name="ddr3_addr[4]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="R7" SLEW="" VCCAUX_IO="" name="ddr3_addr[5]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="V6" SLEW="" VCCAUX_IO="" name="ddr3_addr[6]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="U7" SLEW="" VCCAUX_IO="" name="ddr3_addr[7]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="R8" SLEW="" VCCAUX_IO="" name="ddr3_addr[8]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="V7" SLEW="" VCCAUX_IO="" name="ddr3_addr[9]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="R1" SLEW="" VCCAUX_IO="" name="ddr3_ba[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="P4" SLEW="" VCCAUX_IO="" name="ddr3_ba[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="P2" SLEW="" VCCAUX_IO="" name="ddr3_ba[2]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="M4" SLEW="" VCCAUX_IO="" name="ddr3_cas_n"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL135" PADName="V9" SLEW="" VCCAUX_IO="" name="ddr3_ck_n[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL135" PADName="U9" SLEW="" VCCAUX_IO="" name="ddr3_ck_p[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="N5" SLEW="" VCCAUX_IO="" name="ddr3_cke[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="U8" SLEW="" VCCAUX_IO="" name="ddr3_cs_n[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="L1" SLEW="" VCCAUX_IO="" name="ddr3_dm[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="U1" SLEW="" VCCAUX_IO="" name="ddr3_dm[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="K5" SLEW="" VCCAUX_IO="" name="ddr3_dq[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="U4" SLEW="" VCCAUX_IO="" name="ddr3_dq[10]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="V5" SLEW="" VCCAUX_IO="" name="ddr3_dq[11]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="V1" SLEW="" VCCAUX_IO="" name="ddr3_dq[12]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="T3" SLEW="" VCCAUX_IO="" name="ddr3_dq[13]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="U3" SLEW="" VCCAUX_IO="" name="ddr3_dq[14]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="R3" SLEW="" VCCAUX_IO="" name="ddr3_dq[15]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="L3" SLEW="" VCCAUX_IO="" name="ddr3_dq[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="K3" SLEW="" VCCAUX_IO="" name="ddr3_dq[2]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="L6" SLEW="" VCCAUX_IO="" name="ddr3_dq[3]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="M3" SLEW="" VCCAUX_IO="" name="ddr3_dq[4]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="M1" SLEW="" VCCAUX_IO="" name="ddr3_dq[5]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="L4" SLEW="" VCCAUX_IO="" name="ddr3_dq[6]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="M2" SLEW="" VCCAUX_IO="" name="ddr3_dq[7]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="V4" SLEW="" VCCAUX_IO="" name="ddr3_dq[8]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="T5" SLEW="" VCCAUX_IO="" name="ddr3_dq[9]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL135" PADName="N1" SLEW="" VCCAUX_IO="" name="ddr3_dqs_n[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL135" PADName="V2" SLEW="" VCCAUX_IO="" name="ddr3_dqs_n[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL135" PADName="N2" SLEW="" VCCAUX_IO="" name="ddr3_dqs_p[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="DIFF_SSTL135" PADName="U2" SLEW="" VCCAUX_IO="" name="ddr3_dqs_p[1]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="R5" SLEW="" VCCAUX_IO="" name="ddr3_odt[0]"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="P3" SLEW="" VCCAUX_IO="" name="ddr3_ras_n"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="K6" SLEW="" VCCAUX_IO="" name="ddr3_reset_n"/>}
   puts $mig_prj_file {      <Pin IN_TERM="" IOSTANDARD="SSTL135" PADName="P5" SLEW="" VCCAUX_IO="" name="ddr3_we_n"/>}
   puts $mig_prj_file {    </PinSelection>}
   puts $mig_prj_file {    <System_Control>}
   puts $mig_prj_file {      <Pin Bank="Select Bank" PADName="No connect" name="sys_rst"/>}
   puts $mig_prj_file {      <Pin Bank="Select Bank" PADName="No connect" name="init_calib_complete"/>}
   puts $mig_prj_file {      <Pin Bank="Select Bank" PADName="No connect" name="tg_compare_error"/>}
   puts $mig_prj_file {    </System_Control>}
   puts $mig_prj_file {    <TimingParameters>}
   puts $mig_prj_file {      <Parameters tcke="5.625" tfaw="45" tras="36" trcd="13.5" trefi="7.8" trfc="160" trp="13.5" trrd="7.5" trtp="7.5" twtr="7.5"/>}
   puts $mig_prj_file {    </TimingParameters>}
   puts $mig_prj_file {    <mrBurstLength name="Burst Length">8 - Fixed</mrBurstLength>}
   puts $mig_prj_file {    <mrBurstType name="Read Burst Type and Length">Sequential</mrBurstType>}
   puts $mig_prj_file {    <mrCasLatency name="CAS Latency">5</mrCasLatency>}
   puts $mig_prj_file {    <mrMode name="Mode">Normal</mrMode>}
   puts $mig_prj_file {    <mrDllReset name="DLL Reset">No</mrDllReset>}
   puts $mig_prj_file {    <mrPdMode name="DLL control for precharge PD">Slow Exit</mrPdMode>}
   puts $mig_prj_file {    <emrDllEnable name="DLL Enable">Enable</emrDllEnable>}
   puts $mig_prj_file {    <emrOutputDriveStrength name="Output Driver Impedance Control">RZQ/6</emrOutputDriveStrength>}
   puts $mig_prj_file {    <emrMirrorSelection name="Address Mirroring">Disable</emrMirrorSelection>}
   puts $mig_prj_file {    <emrCSSelection name="Controller Chip Select Pin">Enable</emrCSSelection>}
   puts $mig_prj_file {    <emrRTT name="RTT (nominal) - On Die Termination (ODT)">RZQ/6</emrRTT>}
   puts $mig_prj_file {    <emrPosted name="Additive Latency (AL)">0</emrPosted>}
   puts $mig_prj_file {    <emrOCD name="Write Leveling Enable">Disabled</emrOCD>}
   puts $mig_prj_file {    <emrDQS name="TDQS enable">Enabled</emrDQS>}
   puts $mig_prj_file {    <emrRDQS name="Qoff">Output Buffer Enabled</emrRDQS>}
   puts $mig_prj_file {    <mr2PartialArraySelfRefresh name="Partial-Array Self Refresh">Full Array</mr2PartialArraySelfRefresh>}
   puts $mig_prj_file {    <mr2CasWriteLatency name="CAS write latency">5</mr2CasWriteLatency>}
   puts $mig_prj_file {    <mr2AutoSelfRefresh name="Auto Self Refresh">Enabled</mr2AutoSelfRefresh>}
   puts $mig_prj_file {    <mr2SelfRefreshTempRange name="High Temparature Self Refresh Rate">Normal</mr2SelfRefreshTempRange>}
   puts $mig_prj_file {    <mr2RTTWR name="RTT_WR - Dynamic On Die Termination (ODT)">Dynamic ODT off</mr2RTTWR>}
   puts $mig_prj_file {    <PortInterface>AXI</PortInterface>}
   puts $mig_prj_file {    <AXIParameters>}
   puts $mig_prj_file {      <C0_C_RD_WR_ARB_ALGORITHM>RD_PRI_REG</C0_C_RD_WR_ARB_ALGORITHM>}
   puts $mig_prj_file {      <C0_S_AXI_ADDR_WIDTH>28</C0_S_AXI_ADDR_WIDTH>}
   puts $mig_prj_file {      <C0_S_AXI_DATA_WIDTH>128</C0_S_AXI_DATA_WIDTH>}
   puts $mig_prj_file {      <C0_S_AXI_ID_WIDTH>4</C0_S_AXI_ID_WIDTH>}
   puts $mig_prj_file {      <C0_S_AXI_SUPPORTS_NARROW_BURST>0</C0_S_AXI_SUPPORTS_NARROW_BURST>}
   puts $mig_prj_file {    </AXIParameters>}
   puts $mig_prj_file {  </Controller>}
   puts $mig_prj_file {</Project>}

   close $mig_prj_file
}
# End of write_mig_file_speech_commands_mig_7series_0_1()



##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: tcu
proc create_hier_cell_tcu { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_tcu() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_MM2S

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_dram0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_dram1


  # Create pins
  create_bd_pin -dir I -type rst axi_resetn
  create_bd_pin -dir I -type clk s_axi_lite_aclk

  # Create instance: axi_dma_0, and set properties
  set axi_dma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0 ]
  set_property -dict [ list \
   CONFIG.c_include_s2mm {0} \
   CONFIG.c_include_sg {0} \
   CONFIG.c_m_axi_mm2s_data_width {128} \
   CONFIG.c_m_axis_mm2s_tdata_width {128} \
   CONFIG.c_mm2s_burst_size {256} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
   CONFIG.c_sg_length_width {26} \
 ] $axi_dma_0

  # Create instance: top_artya7100t_0, and set properties
  set block_name top_artya7100t
  set block_cell_name top_artya7100t_0
  if { [catch {set top_artya7100t_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $top_artya7100t_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create interface connections
  connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_MM2S [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins top_artya7100t_0/instruction]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S1 [get_bd_intf_pins M_AXI_MM2S] [get_bd_intf_pins axi_dma_0/M_AXI_MM2S]
  connect_bd_intf_net -intf_net smartconnect_0_M06_AXI [get_bd_intf_pins S_AXI_LITE] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
  connect_bd_intf_net -intf_net top_artya7100t_0_m_axi_dram0 [get_bd_intf_pins m_axi_dram0] [get_bd_intf_pins top_artya7100t_0/m_axi_dram0]
  connect_bd_intf_net -intf_net top_artya7100t_0_m_axi_dram1 [get_bd_intf_pins m_axi_dram1] [get_bd_intf_pins top_artya7100t_0/m_axi_dram1]

  # Create port connections
  connect_bd_net -net microblaze_0_Clk [get_bd_pins s_axi_lite_aclk] [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] [get_bd_pins axi_dma_0/s_axi_lite_aclk] [get_bd_pins top_artya7100t_0/clock]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins axi_resetn] [get_bd_pins axi_dma_0/axi_resetn] [get_bd_pins top_artya7100t_0/reset]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: rfft
proc create_hier_cell_rfft { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_rfft() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_MM2S

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_S2MM

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_SG

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE


  # Create pins
  create_bd_pin -dir I -type rst axi_resetn
  create_bd_pin -dir I -type clk m_axi_mm2s_aclk

  # Create instance: add_0, and set properties
  set add_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 add_0 ]
  set_property -dict [ list \
   CONFIG.Add_Sub_Value {Add} \
   CONFIG.C_Latency {12} \
   CONFIG.C_Mult_Usage {Full_Usage} \
   CONFIG.C_Rate {1} \
   CONFIG.C_Result_Exponent_Width {8} \
   CONFIG.C_Result_Fraction_Width {24} \
   CONFIG.Has_A_TLAST {true} \
   CONFIG.Has_B_TLAST {true} \
   CONFIG.Operation_Type {Add_Subtract} \
   CONFIG.RESULT_TLAST_Behv {OR_all_TLASTs} \
   CONFIG.Result_Precision_Type {Single} \
 ] $add_0

  # Create instance: axi_dma_0, and set properties
  set axi_dma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0 ]
  set_property -dict [ list \
   CONFIG.c_include_s2mm_dre {0} \
   CONFIG.c_include_sg {1} \
   CONFIG.c_m_axis_mm2s_tdata_width {32} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
 ] $axi_dma_0

  # Create instance: fft_config_0, and set properties
  set fft_config_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 fft_config_0 ]
  set_property -dict [ list \
   CONFIG.M_TDATA_NUM_BYTES {3} \
   CONFIG.S_HAS_TREADY {0} \
   CONFIG.S_TDATA_NUM_BYTES {0} \
   CONFIG.TDATA_REMAP {24'b000000000000000000000000} \
 ] $fft_config_0

  # Create instance: hann_window_to_axism_0, and set properties
  set block_name hann_window_to_axism
  set block_cell_name hann_window_to_axism_0
  if { [catch {set hann_window_to_axism_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $hann_window_to_axism_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: mul_0, and set properties
  set mul_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 mul_0 ]
  set_property -dict [ list \
   CONFIG.C_Latency {9} \
   CONFIG.C_Mult_Usage {Full_Usage} \
   CONFIG.C_Rate {1} \
   CONFIG.C_Result_Exponent_Width {8} \
   CONFIG.C_Result_Fraction_Width {24} \
   CONFIG.Has_A_TLAST {true} \
   CONFIG.Has_B_TLAST {true} \
   CONFIG.Operation_Type {Multiply} \
   CONFIG.RESULT_TLAST_Behv {OR_all_TLASTs} \
   CONFIG.Result_Precision_Type {Single} \
 ] $mul_0

  # Create instance: mul_1, and set properties
  set mul_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 mul_1 ]
  set_property -dict [ list \
   CONFIG.C_Latency {9} \
   CONFIG.C_Mult_Usage {Medium_Usage} \
   CONFIG.C_Rate {1} \
   CONFIG.C_Result_Exponent_Width {8} \
   CONFIG.C_Result_Fraction_Width {24} \
   CONFIG.Has_A_TLAST {true} \
   CONFIG.Has_B_TLAST {true} \
   CONFIG.Operation_Type {Multiply} \
   CONFIG.RESULT_TLAST_Behv {OR_all_TLASTs} \
   CONFIG.Result_Precision_Type {Single} \
 ] $mul_1

  # Create instance: mul_2, and set properties
  set mul_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 mul_2 ]
  set_property -dict [ list \
   CONFIG.C_Latency {9} \
   CONFIG.C_Mult_Usage {Full_Usage} \
   CONFIG.C_Rate {1} \
   CONFIG.C_Result_Exponent_Width {8} \
   CONFIG.C_Result_Fraction_Width {24} \
   CONFIG.Has_A_TLAST {true} \
   CONFIG.Has_B_TLAST {true} \
   CONFIG.Operation_Type {Multiply} \
   CONFIG.RESULT_TLAST_Behv {OR_all_TLASTs} \
   CONFIG.Result_Precision_Type {Single} \
 ] $mul_2

  # Create instance: sqrt_0, and set properties
  set sqrt_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 sqrt_0 ]
  set_property -dict [ list \
   CONFIG.C_Latency {29} \
   CONFIG.C_Mult_Usage {No_Usage} \
   CONFIG.C_Rate {1} \
   CONFIG.C_Result_Exponent_Width {8} \
   CONFIG.C_Result_Fraction_Width {24} \
   CONFIG.Has_A_TLAST {true} \
   CONFIG.Operation_Type {Square_root} \
   CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST} \
   CONFIG.Result_Precision_Type {Single} \
 ] $sqrt_0

  # Create instance: to_complex_with_zero_imag_0, and set properties
  set to_complex_with_zero_imag_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 to_complex_with_zero_imag_0 ]
  set_property -dict [ list \
   CONFIG.M_HAS_TLAST {1} \
   CONFIG.M_TDATA_NUM_BYTES {8} \
   CONFIG.S_HAS_TLAST {1} \
   CONFIG.S_TDATA_NUM_BYTES {4} \
   CONFIG.TDATA_REMAP {32'b00000000000000000000000000000000,tdata[31:0]} \
   CONFIG.TKEEP_REMAP {1'b0} \
   CONFIG.TLAST_REMAP {tlast[0]} \
 ] $to_complex_with_zero_imag_0

  # Create instance: to_fixed_0, and set properties
  set to_fixed_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 to_fixed_0 ]
  set_property -dict [ list \
   CONFIG.C_Latency {7} \
   CONFIG.C_Mult_Usage {No_Usage} \
   CONFIG.C_Rate {1} \
   CONFIG.C_Result_Exponent_Width {8} \
   CONFIG.C_Result_Fraction_Width {8} \
   CONFIG.Has_A_TLAST {true} \
   CONFIG.Operation_Type {Float_to_fixed} \
   CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST} \
   CONFIG.Result_Precision_Type {Custom} \
 ] $to_fixed_0

  # Create instance: to_real_imag_0, and set properties
  set to_real_imag_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 to_real_imag_0 ]
  set_property -dict [ list \
   CONFIG.HAS_TLAST {1} \
   CONFIG.M00_TDATA_REMAP {tdata[31:0]} \
   CONFIG.M01_TDATA_REMAP {tdata[31:0]} \
   CONFIG.M02_TDATA_REMAP {tdata[63:32]} \
   CONFIG.M03_TDATA_REMAP {tdata[63:32]} \
   CONFIG.M_TDATA_NUM_BYTES {4} \
   CONFIG.NUM_MI {4} \
   CONFIG.S_TDATA_NUM_BYTES {8} \
 ] $to_real_imag_0

  # Create instance: xfft_0, and set properties
  set xfft_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xfft:9.1 xfft_0 ]
  set_property -dict [ list \
   CONFIG.data_format {floating_point} \
   CONFIG.implementation_options {automatically_select} \
   CONFIG.input_width {32} \
   CONFIG.number_of_stages_using_block_ram_for_data_and_phase_factors {0} \
   CONFIG.output_ordering {natural_order} \
   CONFIG.phase_factor_width {24} \
   CONFIG.target_clock_frequency {100} \
   CONFIG.target_data_throughput {1} \
   CONFIG.transform_length {256} \
 ] $xfft_0

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
 ] $xlconstant_0

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins M_AXI_SG] [get_bd_intf_pins axi_dma_0/M_AXI_SG]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_MM2S [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins mul_0/S_AXIS_A]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S [get_bd_intf_pins M_AXI_MM2S] [get_bd_intf_pins axi_dma_0/M_AXI_MM2S]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_S2MM1 [get_bd_intf_pins M_AXI_S2MM] [get_bd_intf_pins axi_dma_0/M_AXI_S2MM]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M00_AXIS [get_bd_intf_pins mul_1/S_AXIS_A] [get_bd_intf_pins to_real_imag_0/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M01_AXIS [get_bd_intf_pins mul_1/S_AXIS_B] [get_bd_intf_pins to_real_imag_0/M01_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M02_AXIS [get_bd_intf_pins mul_2/S_AXIS_A] [get_bd_intf_pins to_real_imag_0/M02_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M03_AXIS [get_bd_intf_pins mul_2/S_AXIS_B] [get_bd_intf_pins to_real_imag_0/M03_AXIS]
  connect_bd_intf_net -intf_net axis_subset_converter_0_M_AXIS [get_bd_intf_pins to_complex_with_zero_imag_0/M_AXIS] [get_bd_intf_pins xfft_0/S_AXIS_DATA]
  connect_bd_intf_net -intf_net axis_subset_converter_1_M_AXIS [get_bd_intf_pins fft_config_0/M_AXIS] [get_bd_intf_pins xfft_0/S_AXIS_CONFIG]
  connect_bd_intf_net -intf_net floating_point_0_M_AXIS_RESULT [get_bd_intf_pins add_0/S_AXIS_B] [get_bd_intf_pins mul_2/M_AXIS_RESULT]
  connect_bd_intf_net -intf_net floating_point_1_M_AXIS_RESULT [get_bd_intf_pins add_0/M_AXIS_RESULT] [get_bd_intf_pins sqrt_0/S_AXIS_A]
  connect_bd_intf_net -intf_net floating_point_2_M_AXIS_RESULT [get_bd_intf_pins add_0/S_AXIS_A] [get_bd_intf_pins mul_1/M_AXIS_RESULT]
  connect_bd_intf_net -intf_net floating_point_3_M_AXIS_RESULT [get_bd_intf_pins sqrt_0/M_AXIS_RESULT] [get_bd_intf_pins to_fixed_0/S_AXIS_A]
  connect_bd_intf_net -intf_net floating_point_4_M_AXIS_RESULT [get_bd_intf_pins mul_0/M_AXIS_RESULT] [get_bd_intf_pins to_complex_with_zero_imag_0/S_AXIS]
  connect_bd_intf_net -intf_net floating_point_5_M_AXIS_RESULT [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM] [get_bd_intf_pins to_fixed_0/M_AXIS_RESULT]
  connect_bd_intf_net -intf_net hann_window_to_axism_0_M_AXIS [get_bd_intf_pins hann_window_to_axism_0/M_AXIS] [get_bd_intf_pins mul_0/S_AXIS_B]
  connect_bd_intf_net -intf_net smartconnect_0_M04_AXI [get_bd_intf_pins S_AXI_LITE] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
  connect_bd_intf_net -intf_net xfft_0_M_AXIS_DATA [get_bd_intf_pins to_real_imag_0/S_AXIS] [get_bd_intf_pins xfft_0/M_AXIS_DATA]

  # Create port connections
  connect_bd_net -net microblaze_0_Clk [get_bd_pins m_axi_mm2s_aclk] [get_bd_pins add_0/aclk] [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] [get_bd_pins axi_dma_0/m_axi_sg_aclk] [get_bd_pins axi_dma_0/s_axi_lite_aclk] [get_bd_pins fft_config_0/aclk] [get_bd_pins hann_window_to_axism_0/AXIS_ACLK] [get_bd_pins mul_0/aclk] [get_bd_pins mul_1/aclk] [get_bd_pins mul_2/aclk] [get_bd_pins sqrt_0/aclk] [get_bd_pins to_complex_with_zero_imag_0/aclk] [get_bd_pins to_fixed_0/aclk] [get_bd_pins to_real_imag_0/aclk] [get_bd_pins xfft_0/aclk]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins axi_resetn] [get_bd_pins axi_dma_0/axi_resetn] [get_bd_pins fft_config_0/aresetn] [get_bd_pins hann_window_to_axism_0/AXIS_ARESETN] [get_bd_pins to_complex_with_zero_imag_0/aresetn] [get_bd_pins to_real_imag_0/aresetn]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins fft_config_0/s_axis_tvalid] [get_bd_pins xlconstant_0/dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: microblaze_0_local_memory
proc create_hier_cell_microblaze_0_local_memory { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_microblaze_0_local_memory() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode MirroredMaster -vlnv xilinx.com:interface:lmb_rtl:1.0 DLMB

  create_bd_intf_pin -mode MirroredMaster -vlnv xilinx.com:interface:lmb_rtl:1.0 ILMB


  # Create pins
  create_bd_pin -dir I -type clk LMB_Clk
  create_bd_pin -dir I -type rst SYS_Rst

  # Create instance: dlmb_bram_if_cntlr, and set properties
  set dlmb_bram_if_cntlr [ create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 dlmb_bram_if_cntlr ]
  set_property -dict [ list \
   CONFIG.C_ECC {0} \
 ] $dlmb_bram_if_cntlr

  # Create instance: dlmb_v10, and set properties
  set dlmb_v10 [ create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:3.0 dlmb_v10 ]

  # Create instance: ilmb_bram_if_cntlr, and set properties
  set ilmb_bram_if_cntlr [ create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 ilmb_bram_if_cntlr ]
  set_property -dict [ list \
   CONFIG.C_ECC {0} \
 ] $ilmb_bram_if_cntlr

  # Create instance: ilmb_v10, and set properties
  set ilmb_v10 [ create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:3.0 ilmb_v10 ]

  # Create instance: lmb_bram, and set properties
  set lmb_bram [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 lmb_bram ]
  set_property -dict [ list \
   CONFIG.Memory_Type {True_Dual_Port_RAM} \
   CONFIG.use_bram_block {BRAM_Controller} \
 ] $lmb_bram

  # Create interface connections
  connect_bd_intf_net -intf_net microblaze_0_dlmb [get_bd_intf_pins DLMB] [get_bd_intf_pins dlmb_v10/LMB_M]
  connect_bd_intf_net -intf_net microblaze_0_dlmb_bus [get_bd_intf_pins dlmb_bram_if_cntlr/SLMB] [get_bd_intf_pins dlmb_v10/LMB_Sl_0]
  connect_bd_intf_net -intf_net microblaze_0_dlmb_cntlr [get_bd_intf_pins dlmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins lmb_bram/BRAM_PORTA]
  connect_bd_intf_net -intf_net microblaze_0_ilmb [get_bd_intf_pins ILMB] [get_bd_intf_pins ilmb_v10/LMB_M]
  connect_bd_intf_net -intf_net microblaze_0_ilmb_bus [get_bd_intf_pins ilmb_bram_if_cntlr/SLMB] [get_bd_intf_pins ilmb_v10/LMB_Sl_0]
  connect_bd_intf_net -intf_net microblaze_0_ilmb_cntlr [get_bd_intf_pins ilmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins lmb_bram/BRAM_PORTB]

  # Create port connections
  connect_bd_net -net SYS_Rst_1 [get_bd_pins SYS_Rst] [get_bd_pins dlmb_bram_if_cntlr/LMB_Rst] [get_bd_pins dlmb_v10/SYS_Rst] [get_bd_pins ilmb_bram_if_cntlr/LMB_Rst] [get_bd_pins ilmb_v10/SYS_Rst]
  connect_bd_net -net microblaze_0_Clk [get_bd_pins LMB_Clk] [get_bd_pins dlmb_bram_if_cntlr/LMB_Clk] [get_bd_pins dlmb_v10/LMB_Clk] [get_bd_pins ilmb_bram_if_cntlr/LMB_Clk] [get_bd_pins ilmb_v10/LMB_Clk]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: acquisition
proc create_hier_cell_acquisition { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_acquisition() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_S2MM_DMA

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_GPIO

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE_DMA


  # Create pins
  create_bd_pin -dir I SPI_MISO_0
  create_bd_pin -dir O SPI_SCK_0
  create_bd_pin -dir O SPI_SSN_0
  create_bd_pin -dir I -type clk aclk
  create_bd_pin -dir I -type rst aresetn

  # Create instance: adcs747x_to_axism_0, and set properties
  set block_name adcs747x_to_axism
  set block_cell_name adcs747x_to_axism_0
  if { [catch {set adcs747x_to_axism_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $adcs747x_to_axism_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: axi_dma_0, and set properties
  set axi_dma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0 ]
  set_property -dict [ list \
   CONFIG.c_include_mm2s {0} \
   CONFIG.c_include_sg {0} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
 ] $axi_dma_0

  # Create instance: axi_gpio_0, and set properties
  set axi_gpio_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0 ]
  set_property -dict [ list \
   CONFIG.C_ALL_OUTPUTS {1} \
   CONFIG.C_GPIO_WIDTH {1} \
 ] $axi_gpio_0

  # Create instance: mul_add_0, and set properties
  set mul_add_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 mul_add_0 ]
  set_property -dict [ list \
   CONFIG.Add_Sub_Value {Add} \
   CONFIG.C_Latency {17} \
   CONFIG.C_Mult_Usage {Medium_Usage} \
   CONFIG.C_Rate {1} \
   CONFIG.C_Result_Exponent_Width {8} \
   CONFIG.C_Result_Fraction_Width {24} \
   CONFIG.Has_A_TLAST {true} \
   CONFIG.Operation_Type {FMA} \
   CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST} \
   CONFIG.Result_Precision_Type {Single} \
 ] $mul_add_0

  # Create instance: offset_const_0, and set properties
  set offset_const_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 offset_const_0 ]
  set_property -dict [ list \
   CONFIG.M_TDATA_NUM_BYTES {4} \
   CONFIG.S_HAS_TREADY {0} \
   CONFIG.S_TDATA_NUM_BYTES {0} \
   CONFIG.TDATA_REMAP {32'b11000001100010010010000000000010} \
 ] $offset_const_0

  # Create instance: scale_const_0, and set properties
  set scale_const_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 scale_const_0 ]
  set_property -dict [ list \
   CONFIG.M_TDATA_NUM_BYTES {4} \
   CONFIG.S_HAS_TREADY {0} \
   CONFIG.S_TDATA_NUM_BYTES {0} \
   CONFIG.TDATA_REMAP {32'b00111100000010010011111001101110} \
 ] $scale_const_0

  # Create instance: to_float_0, and set properties
  set to_float_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:floating_point:7.1 to_float_0 ]
  set_property -dict [ list \
   CONFIG.A_Precision_Type {Custom} \
   CONFIG.Add_Sub_Value {Both} \
   CONFIG.C_A_Exponent_Width {16} \
   CONFIG.C_Accum_Input_Msb {32} \
   CONFIG.C_Accum_Lsb {-31} \
   CONFIG.C_Accum_Msb {32} \
   CONFIG.C_Latency {7} \
   CONFIG.C_Mult_Usage {No_Usage} \
   CONFIG.C_Rate {1} \
   CONFIG.C_Result_Exponent_Width {8} \
   CONFIG.C_Result_Fraction_Width {24} \
   CONFIG.Has_A_TLAST {true} \
   CONFIG.Operation_Type {Fixed_to_float} \
   CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST} \
   CONFIG.Result_Precision_Type {Single} \
 ] $to_float_0

  # Create instance: xlconstant_2, and set properties
  set xlconstant_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_2 ]

  # Create instance: xlconstant_3, and set properties
  set xlconstant_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_3 ]

  # Create interface connections
  connect_bd_intf_net -intf_net adcs747x_to_axism_0_M_AXIS [get_bd_intf_pins adcs747x_to_axism_0/M_AXIS] [get_bd_intf_pins to_float_0/S_AXIS_A]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_S2MM [get_bd_intf_pins M_AXI_S2MM_DMA] [get_bd_intf_pins axi_dma_0/M_AXI_S2MM]
  connect_bd_intf_net -intf_net axis_subset_converter_0_M_AXIS [get_bd_intf_pins mul_add_0/S_AXIS_B] [get_bd_intf_pins scale_const_0/M_AXIS]
  connect_bd_intf_net -intf_net axis_subset_converter_1_M_AXIS [get_bd_intf_pins mul_add_0/S_AXIS_C] [get_bd_intf_pins offset_const_0/M_AXIS]
  connect_bd_intf_net -intf_net floating_point_0_M_AXIS_RESULT [get_bd_intf_pins mul_add_0/S_AXIS_A] [get_bd_intf_pins to_float_0/M_AXIS_RESULT]
  connect_bd_intf_net -intf_net floating_point_1_M_AXIS_RESULT [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM] [get_bd_intf_pins mul_add_0/M_AXIS_RESULT]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins S_AXI_GPIO] [get_bd_intf_pins axi_gpio_0/S_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M01_AXI [get_bd_intf_pins S_AXI_LITE_DMA] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

  # Create port connections
  connect_bd_net -net SPI_MISO_0_1 [get_bd_pins SPI_MISO_0] [get_bd_pins adcs747x_to_axism_0/SPI_MISO]
  connect_bd_net -net adcs747x_to_axism_0_SPI_SCK [get_bd_pins SPI_SCK_0] [get_bd_pins adcs747x_to_axism_0/SPI_SCK]
  connect_bd_net -net adcs747x_to_axism_0_SPI_SSN [get_bd_pins SPI_SSN_0] [get_bd_pins adcs747x_to_axism_0/SPI_SSN]
  connect_bd_net -net axi_gpio_0_gpio_io_o [get_bd_pins adcs747x_to_axism_0/AXIS_ARESETN] [get_bd_pins axi_gpio_0/gpio_io_o]
  connect_bd_net -net microblaze_0_Clk [get_bd_pins aclk] [get_bd_pins adcs747x_to_axism_0/AXIS_ACLK] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] [get_bd_pins axi_dma_0/s_axi_lite_aclk] [get_bd_pins axi_gpio_0/s_axi_aclk] [get_bd_pins mul_add_0/aclk] [get_bd_pins offset_const_0/aclk] [get_bd_pins scale_const_0/aclk] [get_bd_pins to_float_0/aclk]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins aresetn] [get_bd_pins axi_dma_0/axi_resetn] [get_bd_pins axi_gpio_0/s_axi_aresetn] [get_bd_pins offset_const_0/aresetn] [get_bd_pins scale_const_0/aresetn]
  connect_bd_net -net xlconstant_2_dout [get_bd_pins scale_const_0/s_axis_tvalid] [get_bd_pins xlconstant_2/dout]
  connect_bd_net -net xlconstant_3_dout [get_bd_pins offset_const_0/s_axis_tvalid] [get_bd_pins xlconstant_3/dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set ddr3_sdram [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 ddr3_sdram ]

  set qspi_flash [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:spi_rtl:1.0 qspi_flash ]

  set usb_uart [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:uart_rtl:1.0 usb_uart ]


  # Create ports
  set SPI_MISO_0 [ create_bd_port -dir I SPI_MISO_0 ]
  set SPI_SCK_0 [ create_bd_port -dir O SPI_SCK_0 ]
  set SPI_SSN_0 [ create_bd_port -dir O SPI_SSN_0 ]
  set reset [ create_bd_port -dir I -type rst reset ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_LOW} \
 ] $reset
  set sys_clock [ create_bd_port -dir I -type clk -freq_hz 100000000 sys_clock ]
  set_property -dict [ list \
   CONFIG.PHASE {0.0} \
 ] $sys_clock

  # Create instance: acquisition
  create_hier_cell_acquisition [current_bd_instance .] acquisition

  # Create instance: axi_intc_0, and set properties
  set axi_intc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 axi_intc_0 ]

  # Create instance: axi_quad_spi_0, and set properties
  set axi_quad_spi_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 axi_quad_spi_0 ]
  set_property -dict [ list \
   CONFIG.C_SPI_MEMORY {3} \
   CONFIG.C_TYPE_OF_AXI4_INTERFACE {1} \
   CONFIG.C_XIP_MODE {1} \
   CONFIG.C_XIP_PERF_MODE {1} \
   CONFIG.QSPI_BOARD_INTERFACE {qspi_flash} \
   CONFIG.USE_BOARD_FLOW {true} \
 ] $axi_quad_spi_0

  # Create instance: axi_timer_0, and set properties
  set axi_timer_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer:2.0 axi_timer_0 ]
  set_property -dict [ list \
   CONFIG.enable_timer2 {0} \
 ] $axi_timer_0

  # Create instance: axi_uartlite_0, and set properties
  set axi_uartlite_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0 ]
  set_property -dict [ list \
   CONFIG.C_BAUDRATE {115200} \
   CONFIG.UARTLITE_BOARD_INTERFACE {usb_uart} \
   CONFIG.USE_BOARD_FLOW {true} \
 ] $axi_uartlite_0

  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [ list \
   CONFIG.CLKOUT2_JITTER {114.829} \
   CONFIG.CLKOUT2_PHASE_ERROR {98.575} \
   CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} \
   CONFIG.CLKOUT2_USED {true} \
   CONFIG.CLKOUT3_JITTER {151.636} \
   CONFIG.CLKOUT3_PHASE_ERROR {98.575} \
   CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {50} \
   CONFIG.CLKOUT3_USED {true} \
   CONFIG.CLK_IN1_BOARD_INTERFACE {sys_clock} \
   CONFIG.MMCM_CLKOUT1_DIVIDE {5} \
   CONFIG.MMCM_CLKOUT2_DIVIDE {20} \
   CONFIG.NUM_OUT_CLKS {3} \
   CONFIG.RESET_BOARD_INTERFACE {reset} \
   CONFIG.RESET_PORT {resetn} \
   CONFIG.RESET_TYPE {ACTIVE_LOW} \
   CONFIG.USE_BOARD_FLOW {true} \
 ] $clk_wiz_0

  # Create instance: mdm_1, and set properties
  set mdm_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mdm:3.2 mdm_1 ]

  # Create instance: microblaze_0, and set properties
  set microblaze_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0 ]
  set_property -dict [ list \
   CONFIG.C_DEBUG_ENABLED {1} \
   CONFIG.C_D_AXI {1} \
   CONFIG.C_D_LMB {1} \
   CONFIG.C_I_LMB {1} \
 ] $microblaze_0

  # Create instance: microblaze_0_local_memory
  create_hier_cell_microblaze_0_local_memory [current_bd_instance .] microblaze_0_local_memory

  # Create instance: mig_7series_0, and set properties
  set mig_7series_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.2 mig_7series_0 ]

  # Generate the PRJ File for MIG
  set str_mig_folder [get_property IP_DIR [ get_ips [ get_property CONFIG.Component_Name $mig_7series_0 ] ] ]
  set str_mig_file_name mig_a.prj
  set str_mig_file_path ${str_mig_folder}/${str_mig_file_name}

  write_mig_file_speech_commands_mig_7series_0_1 $str_mig_file_path

  set_property -dict [ list \
   CONFIG.BOARD_MIG_PARAM {ddr3_sdram} \
   CONFIG.MIG_DONT_TOUCH_PARAM {Custom} \
   CONFIG.RESET_BOARD_INTERFACE {reset} \
   CONFIG.XML_INPUT_FILE {mig_a.prj} \
 ] $mig_7series_0

  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]
  set_property -dict [ list \
   CONFIG.RESET_BOARD_INTERFACE {reset} \
   CONFIG.USE_BOARD_FLOW {true} \
 ] $proc_sys_reset_0

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]

  # Create instance: rfft
  create_hier_cell_rfft [current_bd_instance .] rfft

  # Create instance: rst_clk_wiz_0_100M, and set properties
  set rst_clk_wiz_0_100M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_clk_wiz_0_100M ]

  # Create instance: smartconnect_0, and set properties
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
  set_property -dict [ list \
   CONFIG.NUM_CLKS {3} \
   CONFIG.NUM_MI {10} \
   CONFIG.NUM_SI {8} \
 ] $smartconnect_0

  # Create instance: tcu
  create_hier_cell_tcu [current_bd_instance .] tcu

  # Create interface connections
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S [get_bd_intf_pins rfft/M_AXI_MM2S] [get_bd_intf_pins smartconnect_0/S02_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S1 [get_bd_intf_pins smartconnect_0/S05_AXI] [get_bd_intf_pins tcu/M_AXI_MM2S]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_S2MM [get_bd_intf_pins acquisition/M_AXI_S2MM_DMA] [get_bd_intf_pins smartconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_S2MM1 [get_bd_intf_pins rfft/M_AXI_S2MM] [get_bd_intf_pins smartconnect_0/S03_AXI]
  connect_bd_intf_net -intf_net axi_intc_0_interrupt [get_bd_intf_pins axi_intc_0/interrupt] [get_bd_intf_pins microblaze_0/INTERRUPT]
  connect_bd_intf_net -intf_net axi_quad_spi_0_SPI_0 [get_bd_intf_ports qspi_flash] [get_bd_intf_pins axi_quad_spi_0/SPI_0]
  connect_bd_intf_net -intf_net axi_uartlite_0_UART [get_bd_intf_ports usb_uart] [get_bd_intf_pins axi_uartlite_0/UART]
  connect_bd_intf_net -intf_net microblaze_0_M_AXI_DP [get_bd_intf_pins microblaze_0/M_AXI_DP] [get_bd_intf_pins smartconnect_0/S01_AXI]
  connect_bd_intf_net -intf_net microblaze_0_debug [get_bd_intf_pins mdm_1/MBDEBUG_0] [get_bd_intf_pins microblaze_0/DEBUG]
  connect_bd_intf_net -intf_net microblaze_0_dlmb_1 [get_bd_intf_pins microblaze_0/DLMB] [get_bd_intf_pins microblaze_0_local_memory/DLMB]
  connect_bd_intf_net -intf_net microblaze_0_ilmb_1 [get_bd_intf_pins microblaze_0/ILMB] [get_bd_intf_pins microblaze_0_local_memory/ILMB]
  connect_bd_intf_net -intf_net mig_7series_0_DDR3 [get_bd_intf_ports ddr3_sdram] [get_bd_intf_pins mig_7series_0/DDR3]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins acquisition/S_AXI_GPIO] [get_bd_intf_pins smartconnect_0/M00_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M01_AXI [get_bd_intf_pins acquisition/S_AXI_LITE_DMA] [get_bd_intf_pins smartconnect_0/M01_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M02_AXI [get_bd_intf_pins mig_7series_0/S_AXI] [get_bd_intf_pins smartconnect_0/M02_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M03_AXI [get_bd_intf_pins axi_uartlite_0/S_AXI] [get_bd_intf_pins smartconnect_0/M03_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M04_AXI [get_bd_intf_pins rfft/S_AXI_LITE] [get_bd_intf_pins smartconnect_0/M04_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M05_AXI [get_bd_intf_pins axi_timer_0/S_AXI] [get_bd_intf_pins smartconnect_0/M05_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M06_AXI [get_bd_intf_pins smartconnect_0/M06_AXI] [get_bd_intf_pins tcu/S_AXI_LITE]
  connect_bd_intf_net -intf_net smartconnect_0_M07_AXI [get_bd_intf_pins axi_quad_spi_0/AXI_LITE] [get_bd_intf_pins smartconnect_0/M07_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M08_AXI [get_bd_intf_pins axi_intc_0/s_axi] [get_bd_intf_pins smartconnect_0/M08_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M09_AXI [get_bd_intf_pins axi_quad_spi_0/AXI_FULL] [get_bd_intf_pins smartconnect_0/M09_AXI]
  connect_bd_intf_net -intf_net stft_M_AXI_SG [get_bd_intf_pins rfft/M_AXI_SG] [get_bd_intf_pins smartconnect_0/S04_AXI]
  connect_bd_intf_net -intf_net top_artya7100t_0_m_axi_dram0 [get_bd_intf_pins smartconnect_0/S06_AXI] [get_bd_intf_pins tcu/m_axi_dram0]
  connect_bd_intf_net -intf_net top_artya7100t_0_m_axi_dram1 [get_bd_intf_pins smartconnect_0/S07_AXI] [get_bd_intf_pins tcu/m_axi_dram1]

  # Create port connections
  connect_bd_net -net SPI_MISO_0_1 [get_bd_ports SPI_MISO_0] [get_bd_pins acquisition/SPI_MISO_0]
  connect_bd_net -net SYS_Rst_1 [get_bd_pins microblaze_0_local_memory/SYS_Rst] [get_bd_pins proc_sys_reset_0/bus_struct_reset]
  connect_bd_net -net adcs747x_to_axism_0_SPI_SCK [get_bd_ports SPI_SCK_0] [get_bd_pins acquisition/SPI_SCK_0]
  connect_bd_net -net adcs747x_to_axism_0_SPI_SSN [get_bd_ports SPI_SSN_0] [get_bd_pins acquisition/SPI_SSN_0]
  connect_bd_net -net axi_quad_spi_0_ip2intc_irpt [get_bd_pins axi_intc_0/intr] [get_bd_pins axi_quad_spi_0/ip2intc_irpt]
  connect_bd_net -net clk_wiz_0_clk_out2 [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins mig_7series_0/clk_ref_i]
  connect_bd_net -net clk_wiz_0_locked [get_bd_pins clk_wiz_0/locked] [get_bd_pins rst_clk_wiz_0_100M/dcm_locked]
  connect_bd_net -net mdm_1_Debug_SYS_Rst [get_bd_pins mdm_1/Debug_SYS_Rst] [get_bd_pins proc_sys_reset_0/mb_debug_sys_rst]
  connect_bd_net -net microblaze_0_Clk [get_bd_pins acquisition/aclk] [get_bd_pins axi_intc_0/s_axi_aclk] [get_bd_pins axi_quad_spi_0/s_axi4_aclk] [get_bd_pins axi_quad_spi_0/s_axi_aclk] [get_bd_pins axi_timer_0/s_axi_aclk] [get_bd_pins axi_uartlite_0/s_axi_aclk] [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins microblaze_0/Clk] [get_bd_pins microblaze_0_local_memory/LMB_Clk] [get_bd_pins mig_7series_0/sys_clk_i] [get_bd_pins rfft/m_axi_mm2s_aclk] [get_bd_pins rst_clk_wiz_0_100M/slowest_sync_clk] [get_bd_pins smartconnect_0/aclk]
  connect_bd_net -net mig_7series_0_mmcm_locked [get_bd_pins mig_7series_0/mmcm_locked] [get_bd_pins proc_sys_reset_1/dcm_locked]
  connect_bd_net -net mig_7series_0_ui_clk [get_bd_pins mig_7series_0/ui_clk] [get_bd_pins proc_sys_reset_1/slowest_sync_clk] [get_bd_pins smartconnect_0/aclk1]
  connect_bd_net -net mig_7series_0_ui_clk_sync_rst [get_bd_pins mig_7series_0/ui_clk_sync_rst] [get_bd_pins proc_sys_reset_1/ext_reset_in]
  connect_bd_net -net proc_sys_reset_0_mb_reset [get_bd_pins microblaze_0/Reset] [get_bd_pins proc_sys_reset_0/mb_reset]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins acquisition/aresetn] [get_bd_pins axi_timer_0/s_axi_aresetn] [get_bd_pins axi_uartlite_0/s_axi_aresetn] [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins rfft/axi_resetn] [get_bd_pins smartconnect_0/aresetn] [get_bd_pins tcu/axi_resetn]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins mig_7series_0/aresetn] [get_bd_pins proc_sys_reset_1/peripheral_aresetn]
  connect_bd_net -net reset_1 [get_bd_ports reset] [get_bd_pins clk_wiz_0/resetn] [get_bd_pins mig_7series_0/sys_rst] [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins rst_clk_wiz_0_100M/ext_reset_in]
  connect_bd_net -net rst_clk_wiz_0_100M_peripheral_aresetn [get_bd_pins axi_intc_0/s_axi_aresetn] [get_bd_pins axi_quad_spi_0/s_axi4_aresetn] [get_bd_pins axi_quad_spi_0/s_axi_aresetn] [get_bd_pins rst_clk_wiz_0_100M/peripheral_aresetn]
  connect_bd_net -net s_axi_lite_aclk_1 [get_bd_pins axi_quad_spi_0/ext_spi_clk] [get_bd_pins clk_wiz_0/clk_out3] [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_pins smartconnect_0/aclk2] [get_bd_pins tcu/s_axi_lite_aclk]
  connect_bd_net -net sys_clock_1 [get_bd_ports sys_clock] [get_bd_pins clk_wiz_0/clk_in1]

  # Create address segments
  assign_bd_address -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs acquisition/axi_dma_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x41E10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs rfft/axi_dma_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x41E20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs tcu/axi_dma_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs acquisition/axi_gpio_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_intc_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x90000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_quad_spi_0/aximm/MEM0] -force
  assign_bd_address -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg] -force
  assign_bd_address -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_timer_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs microblaze_0_local_memory/dlmb_bram_if_cntlr/SLMB/Mem] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs microblaze_0_local_memory/ilmb_bram_if_cntlr/SLMB/Mem] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces acquisition/axi_dma_0/Data_S2MM] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_SG] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_MM2S] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_S2MM] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tcu/axi_dma_0/Data_MM2S] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram0] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram1] [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force

  # Exclude Address Segments
  exclude_bd_addr_seg -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces acquisition/axi_dma_0/Data_S2MM] [get_bd_addr_segs acquisition/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces acquisition/axi_dma_0/Data_S2MM] [get_bd_addr_segs rfft/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces acquisition/axi_dma_0/Data_S2MM] [get_bd_addr_segs tcu/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces acquisition/axi_dma_0/Data_S2MM] [get_bd_addr_segs acquisition/axi_gpio_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces acquisition/axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_intc_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces acquisition/axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_quad_spi_0/aximm/MEM0]
  exclude_bd_addr_seg -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces acquisition/axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces acquisition/axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_timer_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces acquisition/axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_MM2S] [get_bd_addr_segs acquisition/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_MM2S] [get_bd_addr_segs rfft/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_MM2S] [get_bd_addr_segs tcu/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_MM2S] [get_bd_addr_segs acquisition/axi_gpio_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_intc_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_quad_spi_0/aximm/MEM0]
  exclude_bd_addr_seg -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_timer_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_S2MM] [get_bd_addr_segs acquisition/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_S2MM] [get_bd_addr_segs rfft/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_S2MM] [get_bd_addr_segs tcu/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_S2MM] [get_bd_addr_segs acquisition/axi_gpio_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_intc_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_quad_spi_0/aximm/MEM0]
  exclude_bd_addr_seg -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_timer_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_SG] [get_bd_addr_segs acquisition/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_SG] [get_bd_addr_segs rfft/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_SG] [get_bd_addr_segs tcu/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_SG] [get_bd_addr_segs acquisition/axi_gpio_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_SG] [get_bd_addr_segs axi_intc_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_SG] [get_bd_addr_segs axi_quad_spi_0/aximm/MEM0]
  exclude_bd_addr_seg -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_SG] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_SG] [get_bd_addr_segs axi_timer_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces rfft/axi_dma_0/Data_SG] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/axi_dma_0/Data_MM2S] [get_bd_addr_segs acquisition/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/axi_dma_0/Data_MM2S] [get_bd_addr_segs rfft/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/axi_dma_0/Data_MM2S] [get_bd_addr_segs tcu/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/axi_dma_0/Data_MM2S] [get_bd_addr_segs acquisition/axi_gpio_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_intc_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_quad_spi_0/aximm/MEM0]
  exclude_bd_addr_seg -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_timer_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram0] [get_bd_addr_segs acquisition/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram0] [get_bd_addr_segs rfft/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram0] [get_bd_addr_segs tcu/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram0] [get_bd_addr_segs acquisition/axi_gpio_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram0] [get_bd_addr_segs axi_intc_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram0] [get_bd_addr_segs axi_quad_spi_0/aximm/MEM0]
  exclude_bd_addr_seg -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram0] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram0] [get_bd_addr_segs axi_timer_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram0] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram1] [get_bd_addr_segs acquisition/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram1] [get_bd_addr_segs rfft/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41E20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram1] [get_bd_addr_segs tcu/axi_dma_0/S_AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram1] [get_bd_addr_segs acquisition/axi_gpio_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x41200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram1] [get_bd_addr_segs axi_intc_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x44A10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram1] [get_bd_addr_segs axi_quad_spi_0/aximm/MEM0]
  exclude_bd_addr_seg -offset 0x44A00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram1] [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg]
  exclude_bd_addr_seg -offset 0x41C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram1] [get_bd_addr_segs axi_timer_0/S_AXI/Reg]
  exclude_bd_addr_seg -offset 0x40600000 -range 0x00010000 -target_address_space [get_bd_addr_spaces tcu/top_artya7100t_0/m_axi_dram1] [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg]


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


