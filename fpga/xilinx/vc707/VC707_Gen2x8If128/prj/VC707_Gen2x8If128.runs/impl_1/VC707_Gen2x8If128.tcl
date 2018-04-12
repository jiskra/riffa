proc start_step { step } {
  set stopFile ".stop.rst"
  if {[file isfile .stop.rst]} {
    puts ""
    puts "*** Halting run - EA reset detected ***"
    puts ""
    puts ""
    return -code error
  }
  set beginFile ".$step.begin.rst"
  set platform "$::tcl_platform(platform)"
  set user "$::tcl_platform(user)"
  set pid [pid]
  set host ""
  if { [string equal $platform unix] } {
    if { [info exist ::env(HOSTNAME)] } {
      set host $::env(HOSTNAME)
    }
  } else {
    if { [info exist ::env(COMPUTERNAME)] } {
      set host $::env(COMPUTERNAME)
    }
  }
  set ch [open $beginFile w]
  puts $ch "<?xml version=\"1.0\"?>"
  puts $ch "<ProcessHandle Version=\"1\" Minor=\"0\">"
  puts $ch "    <Process Command=\".planAhead.\" Owner=\"$user\" Host=\"$host\" Pid=\"$pid\">"
  puts $ch "    </Process>"
  puts $ch "</ProcessHandle>"
  close $ch
}

proc end_step { step } {
  set endFile ".$step.end.rst"
  set ch [open $endFile w]
  close $ch
}

proc step_failed { step } {
  set endFile ".$step.error.rst"
  set ch [open $endFile w]
  close $ch
}


start_step init_design
set ACTIVE_STEP init_design
set rc [catch {
  create_msg_db init_design.pb
  create_project -in_memory -part xc7vx485tffg1761-2
  set_property board_part xilinx.com:vc707:part0:1.1 [current_project]
  set_property design_mode GateLvl [current_fileset]
  set_param project.singleFileAddWarning.threshold 0
  set_property webtalk.parent_dir /home/phung/Documents/fpga_overlay/riffa/fpga/xilinx/vc707/VC707_Gen2x8If128/prj/VC707_Gen2x8If128.cache/wt [current_project]
  set_property parent.project_path /home/phung/Documents/fpga_overlay/riffa/fpga/xilinx/vc707/VC707_Gen2x8If128/prj/VC707_Gen2x8If128.xpr [current_project]
  set_property ip_cache_permissions disable [current_project]
  set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY} [current_project]
  add_files -quiet /home/phung/Documents/fpga_overlay/riffa/fpga/xilinx/vc707/VC707_Gen2x8If128/prj/VC707_Gen2x8If128.runs/synth_1/VC707_Gen2x8If128.dcp
  read_ip -quiet /home/phung/Documents/fpga_overlay/riffa/fpga/xilinx/vc707/VC707_Gen2x8If128/ip/PCIeGen2x8If128.xci
  set_property is_locked true [get_files /home/phung/Documents/fpga_overlay/riffa/fpga/xilinx/vc707/VC707_Gen2x8If128/ip/PCIeGen2x8If128.xci]
  read_xdc /home/phung/Documents/fpga_overlay/riffa/fpga/xilinx/vc707/VC707_Gen2x8If128/constr/VC707_Gen2x8If128.xdc
  link_design -top VC707_Gen2x8If128 -part xc7vx485tffg1761-2
  close_msg_db -file init_design.pb
} RESULT]
if {$rc} {
  step_failed init_design
  return -code error $RESULT
} else {
  end_step init_design
  unset ACTIVE_STEP 
}

start_step opt_design
set ACTIVE_STEP opt_design
set rc [catch {
  create_msg_db opt_design.pb
  opt_design 
  write_checkpoint -force VC707_Gen2x8If128_opt.dcp
  catch { report_drc -file VC707_Gen2x8If128_drc_opted.rpt }
  close_msg_db -file opt_design.pb
} RESULT]
if {$rc} {
  step_failed opt_design
  return -code error $RESULT
} else {
  end_step opt_design
  unset ACTIVE_STEP 
}

start_step place_design
set ACTIVE_STEP place_design
set rc [catch {
  create_msg_db place_design.pb
  implement_debug_core 
  place_design 
  write_checkpoint -force VC707_Gen2x8If128_placed.dcp
  catch { report_io -file VC707_Gen2x8If128_io_placed.rpt }
  catch { report_utilization -file VC707_Gen2x8If128_utilization_placed.rpt -pb VC707_Gen2x8If128_utilization_placed.pb }
  catch { report_control_sets -verbose -file VC707_Gen2x8If128_control_sets_placed.rpt }
  close_msg_db -file place_design.pb
} RESULT]
if {$rc} {
  step_failed place_design
  return -code error $RESULT
} else {
  end_step place_design
  unset ACTIVE_STEP 
}

start_step route_design
set ACTIVE_STEP route_design
set rc [catch {
  create_msg_db route_design.pb
  route_design 
  write_checkpoint -force VC707_Gen2x8If128_routed.dcp
  catch { report_drc -file VC707_Gen2x8If128_drc_routed.rpt -pb VC707_Gen2x8If128_drc_routed.pb -rpx VC707_Gen2x8If128_drc_routed.rpx }
  catch { report_methodology -file VC707_Gen2x8If128_methodology_drc_routed.rpt -rpx VC707_Gen2x8If128_methodology_drc_routed.rpx }
  catch { report_power -file VC707_Gen2x8If128_power_routed.rpt -pb VC707_Gen2x8If128_power_summary_routed.pb -rpx VC707_Gen2x8If128_power_routed.rpx }
  catch { report_route_status -file VC707_Gen2x8If128_route_status.rpt -pb VC707_Gen2x8If128_route_status.pb }
  catch { report_clock_utilization -file VC707_Gen2x8If128_clock_utilization_routed.rpt }
  catch { report_timing_summary -warn_on_violation -max_paths 10 -file VC707_Gen2x8If128_timing_summary_routed.rpt -rpx VC707_Gen2x8If128_timing_summary_routed.rpx }
  close_msg_db -file route_design.pb
} RESULT]
if {$rc} {
  write_checkpoint -force VC707_Gen2x8If128_routed_error.dcp
  step_failed route_design
  return -code error $RESULT
} else {
  end_step route_design
  unset ACTIVE_STEP 
}

start_step write_bitstream
set ACTIVE_STEP write_bitstream
set rc [catch {
  create_msg_db write_bitstream.pb
  set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY} [current_project]
  catch { write_mem_info -force VC707_Gen2x8If128.mmi }
  write_bitstream -force VC707_Gen2x8If128.bit 
  catch {write_debug_probes -no_partial_ltxfile -quiet -force debug_nets}
  catch {file copy -force debug_nets.ltx VC707_Gen2x8If128.ltx}
  close_msg_db -file write_bitstream.pb
} RESULT]
if {$rc} {
  step_failed write_bitstream
  return -code error $RESULT
} else {
  end_step write_bitstream
  unset ACTIVE_STEP 
}

