#!/bin/bash
# check_progress.sh
# Monitor progress of all simulation job arrays (power, assurance, type I error)
# Run from head node: bash /shared/taurinelc/cluster/check_progress.sh
#
# Options:
#   --power     Show only power analysis progress
#   --assurance Show only assurance analysis progress
#   --type1     Show only Type I error analysis progress
#   --report    Generate comprehensive markdown report and save to file
#   (no args)   Show all simulations

# Cost per hour (USD) - update these if instance types change
HEAD_NODE_COST=0.083    # t3.large
COMPUTE_NODE_COST=0.17  # c5.xlarge

# Progress history directory
PROGRESS_DIR="/shared/taurinelc/logs"
TIMING_FILE="$PROGRESS_DIR/.simulation_timing"
REPORT_DIR="/shared/taurinelc/data/cached_results"
STUCK_THRESHOLD=120  # seconds without progress before flagging as stuck

# Global variables for cost tracking
declare -A SIM_ELAPSED_SECONDS
declare -A SIM_ESTIMATED_REMAINING
declare -A SIM_STATUS  # completed, running, not_started

# Parse arguments
SHOW_POWER=false
SHOW_ASSURANCE=false
SHOW_TYPE1=false
GENERATE_REPORT=false

if [ $# -eq 0 ]; then
  SHOW_POWER=true
  SHOW_ASSURANCE=true
  SHOW_TYPE1=true
else
  for arg in "$@"; do
    case $arg in
      --power) SHOW_POWER=true ;;
      --assurance) SHOW_ASSURANCE=true ;;
      --type1) SHOW_TYPE1=true ;;
      --report) GENERATE_REPORT=true; SHOW_POWER=true; SHOW_ASSURANCE=true; SHOW_TYPE1=true ;;
      *) echo "Unknown option: $arg"; exit 1 ;;
    esac
  done
fi

# Helper functions
parse_time_to_seconds() {
  local time_str=$1
  local seconds=0

  if [[ "$time_str" =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
    seconds=$((${BASH_REMATCH[1]} * 3600 + ${BASH_REMATCH[2]} * 60 + ${BASH_REMATCH[3]}))
  elif [[ "$time_str" =~ ^([0-9]+):([0-9]+)$ ]]; then
    seconds=$((${BASH_REMATCH[1]} * 60 + ${BASH_REMATCH[2]}))
  fi
  echo $seconds
}

format_duration() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local mins=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))

  if [ $hours -gt 0 ]; then
    printf "%dh %dm %ds" $hours $mins $secs
  elif [ $mins -gt 0 ]; then
    printf "%dm %ds" $mins $secs
  else
    printf "%ds" $secs
  fi
}

# Get elapsed time from log file (parses start/end timestamps)
get_log_elapsed_seconds() {
  local logfile=$1

  # Look for "Start time:" and "End time:" in log
  # Format: "Start time: Sun Jan  4 06:44:08 UTC 2026"
  local start_line=$(grep "^Start time:" "$logfile" 2>/dev/null | head -1)
  local end_line=$(grep "^End time:" "$logfile" 2>/dev/null | tail -1)

  if [ -n "$start_line" ] && [ -n "$end_line" ]; then
    # Extract the timestamp after "Start time: " or "End time: "
    local start_time="${start_line#Start time: }"
    local end_time="${end_line#End time: }"

    # Parse with date command (Linux format)
    local start_epoch=$(date -d "$start_time" +%s 2>/dev/null)
    local end_epoch=$(date -d "$end_time" +%s 2>/dev/null)

    if [ -n "$start_epoch" ] && [ -n "$end_epoch" ] && [ "$end_epoch" -gt "$start_epoch" ]; then
      echo $((end_epoch - start_epoch))
      return
    fi
  fi

  echo 0
}

# Load saved timing data
load_timing_data() {
  if [ -f "$TIMING_FILE" ]; then
    while IFS=',' read -r sim_type elapsed_secs; do
      SIM_ELAPSED_SECONDS[$sim_type]=$elapsed_secs
    done < "$TIMING_FILE"
  fi
}

# Save timing data for a completed simulation
save_timing_data() {
  local sim_type=$1
  local elapsed_secs=$2

  # Update in-memory
  SIM_ELAPSED_SECONDS[$sim_type]=$elapsed_secs

  # Write all timing data to file
  > "$TIMING_FILE"
  for key in "${!SIM_ELAPSED_SECONDS[@]}"; do
    echo "$key,${SIM_ELAPSED_SECONDS[$key]}" >> "$TIMING_FILE"
  done
}

# Function to check progress of a single simulation type
check_simulation() {
  local sim_type=$1
  local total_reps=$2
  local description=$3
  local slurm_script=$4

  local progress_file="$PROGRESS_DIR/.${sim_type}_progress_history"
  local current_time=$(date +%s)

  echo ""
  echo "┌──────────────────────────────────────────────────────────────────┐"
  echo "│  $description"
  echo "└──────────────────────────────────────────────────────────────────┘"
  echo ""

  # Check for running jobs of this type
  # Note: SLURM truncates job names, so we match on the prefix
  local job_prefix="${sim_type:0:8}"  # First 8 chars to match truncated names
  local job_info=$(/opt/slurm/bin/squeue 2>/dev/null | grep "${job_prefix}" || true)
  local running_count=0
  local pending_count=0
  local max_elapsed=""
  if [ -n "$job_info" ]; then
    running_count=$(echo "$job_info" | grep "  R  " | wc -l | tr -d ' ')
    pending_count=$(echo "$job_info" | grep "  PD  " | wc -l | tr -d ' ')
    max_elapsed=$(echo "$job_info" | grep "  R  " | awk '{print $6}' | sort -t: -k1,1nr -k2,2nr | head -1)
  fi
  # Ensure counts are integers
  running_count=${running_count:-0}
  pending_count=${pending_count:-0}

  if [ "$running_count" -gt 0 ] || [ "$pending_count" -gt 0 ]; then
    echo "Status: $running_count running, $pending_count pending"
    if [ -n "$max_elapsed" ]; then
      echo "Elapsed: $max_elapsed"
    fi
  else
    # Check if any results exist
    local result_count=$(ls /shared/taurinelc/data/cached_results/${sim_type}_n*.rds 2>/dev/null | wc -l | tr -d ' ')
    if [ "$result_count" -gt 0 ]; then
      echo "Status: COMPLETED (no jobs running, $result_count/7 results saved)"
    else
      echo "Status: NOT STARTED"
    fi
  fi
  echo ""

  # Load previous progress for stuck detection
  declare -A prev_counts
  declare -A prev_times
  if [ -f "$progress_file" ]; then
    while IFS=',' read -r node count timestamp; do
      prev_counts[$node]=$count
      prev_times[$node]=$timestamp
    done < "$progress_file"
  fi

  # Clear progress file for fresh write
  > "$progress_file"

  # Count completed simulations per node
  echo "Progress by Sample Size:"
  local total_completed=0
  local total_remaining=0
  local total_possible=$((7 * total_reps))
  declare -a node_counts
  declare -a node_remaining
  declare -a stuck_nodes

  for i in 1 2 3 4 5 6 7; do
    local n=$((120 + (i-1)*60))
    local logfile=$(ls -t /shared/taurinelc/logs/${sim_type}_n${i}_*.out 2>/dev/null | head -1)
    local stuck_flag=""

    if [ -n "$logfile" ]; then
      local count=$(grep -c 'All 4 chains finished' "$logfile" 2>/dev/null || echo 0)
      local remaining=$((total_reps - count))
      node_counts[$i]=$count
      node_remaining[$i]=$remaining
      total_completed=$((total_completed + count))
      total_remaining=$((total_remaining + remaining))

      # Check if node is stuck
      local prev_count=${prev_counts[$i]:-0}
      local prev_time=${prev_times[$i]:-$current_time}

      if [ "$count" -eq "$prev_count" ] && [ "$count" -lt "$total_reps" ] && [ "$count" -gt 0 ]; then
        local time_stuck=$((current_time - prev_time))
        if [ "$time_stuck" -gt "$STUCK_THRESHOLD" ]; then
          stuck_flag=" !! STUCK (${time_stuck}s)"
          stuck_nodes+=($i)
        fi
        echo "$i,$count,$prev_time" >> "$progress_file"
      else
        echo "$i,$count,$current_time" >> "$progress_file"
      fi

      # Progress bar
      local pct=$((count * 100 / total_reps))
      local filled=$((pct / 10))
      local bar=""
      for j in $(seq 1 10); do
        if [ $j -le $filled ]; then
          bar="${bar}#"
        else
          bar="${bar}-"
        fi
      done
      printf "  N=%-3d: %3d/%-3d [%s] %3d%%%s\n" $n $count $total_reps "$bar" $pct "$stuck_flag"
    else
      node_counts[$i]=0
      node_remaining[$i]=$total_reps
      total_remaining=$((total_remaining + total_reps))
      printf "  N=%-3d: %3d/%-3d [----------]   0%% (no log)\n" $n 0 $total_reps
      echo "$i,0,$current_time" >> "$progress_file"
    fi
  done

  echo ""
  local overall_pct=0
  if [ "$total_possible" -gt 0 ]; then
    overall_pct=$((total_completed * 100 / total_possible))
  fi
  echo "Overall: $total_completed/$total_possible ($overall_pct%)"

  # Count saved results first (needed for time estimates)
  local saved_count=0
  for i in 1 2 3 4 5 6 7; do
    local n=$((120 + (i-1)*60))
    if [ -f "/shared/taurinelc/data/cached_results/${sim_type}_n${n}.rds" ]; then
      saved_count=$((saved_count + 1))
    fi
  done

  # Time estimates and tracking
  local elapsed_seconds=0
  local remaining_seconds=0
  local sim_total_time=0

  if [ "$running_count" -gt 0 ] && [ -n "$max_elapsed" ] && [ "$total_completed" -gt 0 ]; then
    # Currently running - estimate based on progress
    elapsed_seconds=$(parse_time_to_seconds "$max_elapsed")
    SIM_STATUS[$sim_type]="running"

    # Estimate based on slowest node (N=480)
    local slowest_completed=${node_counts[7]:-0}
    local slowest_remaining=${node_remaining[7]:-$total_reps}

    if [ "$slowest_completed" -gt 0 ] && [ "$slowest_remaining" -gt 0 ]; then
      local slowest_rate=$(echo "scale=4; $slowest_completed / $elapsed_seconds" | bc)
      remaining_seconds=$(echo "scale=0; $slowest_remaining / $slowest_rate" | bc 2>/dev/null || echo 0)
      sim_total_time=$((elapsed_seconds + remaining_seconds))
      echo "Elapsed: $(format_duration $elapsed_seconds)"
      echo "Est. remaining: $(format_duration $remaining_seconds)"
      echo "Est. total: $(format_duration $sim_total_time)"
    fi

    SIM_ELAPSED_SECONDS[$sim_type]=$elapsed_seconds
    SIM_ESTIMATED_REMAINING[$sim_type]=$remaining_seconds

  elif [ "$saved_count" -eq 7 ]; then
    # Completed - calculate actual elapsed time from logs
    SIM_STATUS[$sim_type]="completed"
    local max_elapsed_secs=0

    for i in 1 2 3 4 5 6 7; do
      local logfile=$(ls -t /shared/taurinelc/logs/${sim_type}_n${i}_*.out 2>/dev/null | head -1)
      if [ -n "$logfile" ]; then
        local log_elapsed=$(get_log_elapsed_seconds "$logfile")
        if [ "$log_elapsed" -gt "$max_elapsed_secs" ]; then
          max_elapsed_secs=$log_elapsed
        fi
      fi
    done

    # If we got valid timing, save it
    if [ "$max_elapsed_secs" -gt 0 ]; then
      save_timing_data "$sim_type" "$max_elapsed_secs"
      echo "Actual runtime: $(format_duration $max_elapsed_secs)"
    elif [ -n "${SIM_ELAPSED_SECONDS[$sim_type]}" ]; then
      # Use previously saved timing
      echo "Recorded runtime: $(format_duration ${SIM_ELAPSED_SECONDS[$sim_type]})"
    fi

    SIM_ESTIMATED_REMAINING[$sim_type]=0

  else
    # Not started
    SIM_STATUS[$sim_type]="not_started"
    SIM_ELAPSED_SECONDS[$sim_type]=0
    SIM_ESTIMATED_REMAINING[$sim_type]=0
  fi

  # Display saved results
  echo ""
  echo "Saved Results:"
  for i in 1 2 3 4 5 6 7; do
    local n=$((120 + (i-1)*60))
    if [ -f "/shared/taurinelc/data/cached_results/${sim_type}_n${n}.rds" ]; then
      echo "  N=$n: SAVED"
    else
      echo "  N=$n: pending"
    fi
  done

  if [ $saved_count -eq 7 ]; then
    echo ""
    echo ">> All $description results saved!"
  fi

  # Stuck node remediation
  if [ ${#stuck_nodes[@]} -gt 0 ]; then
    echo ""
    echo "!! STUCK NODES DETECTED !!"
    echo "No progress in ${STUCK_THRESHOLD}+ seconds:"

    local current_job=$(echo "$job_info" | grep "  R  " | head -1 | awk '{print $1}' | cut -d'_' -f1)

    for node in "${stuck_nodes[@]}"; do
      local n=$((120 + (node-1)*60))
      echo "  Node $node (N=$n)"
    done
    echo ""
    echo "To restart, cancel and resubmit:"
    for node in "${stuck_nodes[@]}"; do
      echo "  scancel ${current_job}_${node} && sbatch --array=$node cluster/${slurm_script}"
    done
  fi
}

# Load previously saved timing data
load_timing_data

# Main output
echo "===================================================================="
echo "  TAURINELC SIMULATION PROGRESS REPORT"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "===================================================================="

# Show queue status
echo ""
echo "SLURM Queue:"
/opt/slurm/bin/squeue 2>/dev/null || squeue

# Check each simulation type
if [ "$SHOW_POWER" = true ]; then
  check_simulation "power" 100 "POWER ANALYSIS (100 reps/N)" "slurm_power_array.sh"
fi

if [ "$SHOW_ASSURANCE" = true ]; then
  check_simulation "assurance" 100 "ASSURANCE ANALYSIS (100 reps/N)" "slurm_assurance_array.sh"
fi

if [ "$SHOW_TYPE1" = true ]; then
  check_simulation "type1" 500 "TYPE I ERROR ANALYSIS (500 reps/N)" "slurm_type1_array.sh"
fi

# Summary section
echo ""
echo "===================================================================="
echo "  SUMMARY"
echo "===================================================================="
echo ""

# Count total saved results
power_saved=$(ls /shared/taurinelc/data/cached_results/power_n*.rds 2>/dev/null | wc -l | tr -d ' ')
assurance_saved=$(ls /shared/taurinelc/data/cached_results/assurance_n*.rds 2>/dev/null | wc -l | tr -d ' ')
type1_saved=$(ls /shared/taurinelc/data/cached_results/type1_n*.rds 2>/dev/null | wc -l | tr -d ' ')

printf "  %-20s %s/7 saved\n" "Power:" "$power_saved"
printf "  %-20s %s/7 saved\n" "Assurance:" "$assurance_saved"
printf "  %-20s %s/7 saved\n" "Type I Error:" "$type1_saved"

# Check if all complete
if [ "$power_saved" -eq 7 ] && [ "$assurance_saved" -eq 7 ] && [ "$type1_saved" -eq 7 ]; then
  echo ""
  echo ">> ALL SIMULATIONS COMPLETE!"
  echo "   Run: Rscript cluster/combine_results.R"
elif [ "$power_saved" -eq 7 ] && [ "$assurance_saved" -eq 7 ]; then
  echo ""
  echo "Power and Assurance complete. Type I error in progress/pending."
  echo "Next: sbatch cluster/slurm_type1_array.sh (if not running)"
elif [ "$power_saved" -eq 7 ]; then
  echo ""
  echo "Power complete. Submit remaining simulations:"
  echo "  sbatch cluster/slurm_assurance_array.sh"
  echo "  sbatch cluster/slurm_type1_array.sh"
fi

# Comprehensive time and cost estimates
echo ""
echo "===================================================================="
echo "  TIME & COST ESTIMATES"
echo "===================================================================="
echo ""

# Estimated times for not-started simulations (based on completed ones or defaults)
# Type I error takes ~5x longer due to 500 reps vs 100
DEFAULT_POWER_TIME=3600      # 1 hour default estimate
DEFAULT_ASSURANCE_TIME=3600  # 1 hour default estimate
DEFAULT_TYPE1_TIME=18000     # 5 hours default estimate (500 reps)

# Use actual completed times to estimate others
if [ -n "${SIM_ELAPSED_SECONDS[power]}" ] && [ "${SIM_ELAPSED_SECONDS[power]}" -gt 0 ]; then
  DEFAULT_POWER_TIME=${SIM_ELAPSED_SECONDS[power]}
  DEFAULT_ASSURANCE_TIME=${SIM_ELAPSED_SECONDS[power]}  # Similar workload
  DEFAULT_TYPE1_TIME=$((${SIM_ELAPSED_SECONDS[power]} * 5))  # 5x reps
fi

if [ -n "${SIM_ELAPSED_SECONDS[assurance]}" ] && [ "${SIM_ELAPSED_SECONDS[assurance]}" -gt 0 ]; then
  DEFAULT_ASSURANCE_TIME=${SIM_ELAPSED_SECONDS[assurance]}
fi

if [ -n "${SIM_ELAPSED_SECONDS[type1]}" ] && [ "${SIM_ELAPSED_SECONDS[type1]}" -gt 0 ]; then
  DEFAULT_TYPE1_TIME=${SIM_ELAPSED_SECONDS[type1]}
fi

# Calculate totals
total_completed_time=0
total_running_elapsed=0
total_running_remaining=0
total_not_started_time=0
running_nodes=0

echo "By Simulation:"
echo ""

# Power
power_time=0
power_label=""
case "${SIM_STATUS[power]}" in
  completed)
    power_time=${SIM_ELAPSED_SECONDS[power]:-$DEFAULT_POWER_TIME}
    total_completed_time=$((total_completed_time + power_time))
    power_label="completed"
    ;;
  running)
    power_elapsed=${SIM_ELAPSED_SECONDS[power]:-0}
    power_remaining=${SIM_ESTIMATED_REMAINING[power]:-0}
    power_time=$((power_elapsed + power_remaining))
    total_running_elapsed=$((total_running_elapsed + power_elapsed))
    total_running_remaining=$((total_running_remaining + power_remaining))
    running_nodes=7
    power_label="running"
    ;;
  *)
    power_time=$DEFAULT_POWER_TIME
    total_not_started_time=$((total_not_started_time + power_time))
    power_label="estimated"
    ;;
esac
printf "  Power:      %12s (%s)\n" "$(format_duration $power_time)" "$power_label"

# Assurance
assurance_time=0
assurance_label=""
case "${SIM_STATUS[assurance]}" in
  completed)
    assurance_time=${SIM_ELAPSED_SECONDS[assurance]:-$DEFAULT_ASSURANCE_TIME}
    total_completed_time=$((total_completed_time + assurance_time))
    assurance_label="completed"
    ;;
  running)
    assurance_elapsed=${SIM_ELAPSED_SECONDS[assurance]:-0}
    assurance_remaining=${SIM_ESTIMATED_REMAINING[assurance]:-0}
    assurance_time=$((assurance_elapsed + assurance_remaining))
    total_running_elapsed=$((total_running_elapsed + assurance_elapsed))
    total_running_remaining=$((total_running_remaining + assurance_remaining))
    running_nodes=7
    assurance_label="running"
    ;;
  *)
    assurance_time=$DEFAULT_ASSURANCE_TIME
    total_not_started_time=$((total_not_started_time + assurance_time))
    assurance_label="estimated"
    ;;
esac
printf "  Assurance:  %12s (%s)\n" "$(format_duration $assurance_time)" "$assurance_label"

# Type I Error
type1_time=0
type1_label=""
case "${SIM_STATUS[type1]}" in
  completed)
    type1_time=${SIM_ELAPSED_SECONDS[type1]:-$DEFAULT_TYPE1_TIME}
    total_completed_time=$((total_completed_time + type1_time))
    type1_label="completed"
    ;;
  running)
    type1_elapsed=${SIM_ELAPSED_SECONDS[type1]:-0}
    type1_remaining=${SIM_ESTIMATED_REMAINING[type1]:-0}
    type1_time=$((type1_elapsed + type1_remaining))
    total_running_elapsed=$((total_running_elapsed + type1_elapsed))
    total_running_remaining=$((total_running_remaining + type1_remaining))
    running_nodes=7
    type1_label="running"
    ;;
  *)
    type1_time=$DEFAULT_TYPE1_TIME
    total_not_started_time=$((total_not_started_time + type1_time))
    type1_label="estimated"
    ;;
esac
printf "  Type I:     %12s (%s)\n" "$(format_duration $type1_time)" "$type1_label"

echo ""
echo "Time Summary:"
total_project_time=$((total_completed_time + total_running_elapsed + total_running_remaining + total_not_started_time))
printf "  Completed:        %12s\n" "$(format_duration $total_completed_time)"
if [ "$total_running_elapsed" -gt 0 ]; then
  printf "  Running elapsed:  %12s\n" "$(format_duration $total_running_elapsed)"
  printf "  Running remaining:%12s\n" "$(format_duration $total_running_remaining)"
fi
if [ "$total_not_started_time" -gt 0 ]; then
  printf "  Not started (est):%12s\n" "$(format_duration $total_not_started_time)"
fi
printf "  ─────────────────────────────\n"
printf "  Total project:    %12s\n" "$(format_duration $total_project_time)"

# Cost calculations
echo ""
echo "Cost Summary:"

# Completed cost (7 nodes for duration of each completed sim)
completed_hours=$(echo "scale=4; $total_completed_time / 3600" | bc)
completed_compute_cost=$(echo "scale=4; 7 * $COMPUTE_NODE_COST * $completed_hours" | bc)

# Running cost
running_hours=$(echo "scale=4; $total_running_elapsed / 3600" | bc)
running_compute_cost=$(echo "scale=4; 7 * $COMPUTE_NODE_COST * $running_hours" | bc)

# Not started estimate
not_started_hours=$(echo "scale=4; $total_not_started_time / 3600" | bc)
not_started_compute_cost=$(echo "scale=4; 7 * $COMPUTE_NODE_COST * $not_started_hours" | bc)

# Current cost (completed + running elapsed)
current_compute_cost=$(echo "scale=4; $completed_compute_cost + $running_compute_cost" | bc)

# Projected remaining (running remaining + not started)
remaining_hours=$(echo "scale=4; ($total_running_remaining + $total_not_started_time) / 3600" | bc)
remaining_compute_cost=$(echo "scale=4; 7 * $COMPUTE_NODE_COST * $remaining_hours" | bc)

# Total projected
total_hours=$(echo "scale=4; $total_project_time / 3600" | bc)
total_compute_cost=$(echo "scale=4; 7 * $COMPUTE_NODE_COST * $total_hours" | bc)
total_head_cost=$(echo "scale=4; $HEAD_NODE_COST * $total_hours" | bc)
total_cost=$(echo "scale=4; $total_compute_cost + $total_head_cost" | bc)

# Current totals (completed + running elapsed)
current_hours=$(echo "scale=4; ($total_completed_time + $total_running_elapsed) / 3600" | bc)
current_head_cost=$(echo "scale=4; $HEAD_NODE_COST * $current_hours" | bc)
current_total_cost=$(echo "scale=4; $current_compute_cost + $current_head_cost" | bc)

printf "  Compute (7 nodes @ \$%.3f/hr):\n" $COMPUTE_NODE_COST
printf "    Completed:      \$%8.2f\n" $completed_compute_cost
if [ "$total_running_elapsed" -gt 0 ]; then
  printf "    Running:        \$%8.2f\n" $running_compute_cost
fi
printf "    ─────────────────────────\n"
printf "    Current total:  \$%8.2f\n" $current_compute_cost
echo ""
if [ "$total_not_started_time" -gt 0 ] || [ "$total_running_remaining" -gt 0 ]; then
  printf "  Projected remaining: \$%8.2f\n" $remaining_compute_cost
fi
printf "  Projected total:     \$%8.2f (compute) + \$%.2f (head) = \$%.2f\n" $total_compute_cost $total_head_cost $total_cost

# Generate comprehensive markdown report if requested
if [ "$GENERATE_REPORT" = true ]; then
  REPORT_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
  REPORT_FILE="$REPORT_DIR/simulation_report_${REPORT_TIMESTAMP}.md"

  echo ""
  echo "===================================================================="
  echo "  GENERATING COMPREHENSIVE REPORT"
  echo "===================================================================="

  mkdir -p "$REPORT_DIR"

  cat > "$REPORT_FILE" << 'REPORT_HEADER'
# Taurine Long COVID Trial Simulation Report

**Simulation Assurance Documentation**

REPORT_HEADER

  # Add generation timestamp
  echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"

  # Table of Contents
  cat >> "$REPORT_FILE" << 'TOC'
## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Trial Design Parameters](#trial-design-parameters)
3. [Statistical Model](#statistical-model)
4. [Simulation Configuration](#simulation-configuration)
5. [Infrastructure](#infrastructure)
6. [Simulation Results](#simulation-results)
7. [Quality Assurance](#quality-assurance)
8. [Appendix: Technical Details](#appendix-technical-details)

---

TOC

  # Executive Summary
  cat >> "$REPORT_FILE" << 'EXEC_SUMMARY'
## Executive Summary

This report documents the simulation-based sample size determination for a Phase 2 clinical trial investigating taurine supplementation in Long COVID patients. The trial employs a Bayesian adaptive design with two co-primary endpoints.

### Key Design Features

- **Co-primary Outcomes:** TMT B/A Ratio (cognition) and MFIS (fatigue)
- **Randomization:** 2:1 (treatment:control)
- **Decision Rule:** Declare success if P(benefit) ≥ 0.95 for BOTH outcomes
- **Adaptive Design:** Sequential monitoring with futility stopping

### Simulation Components

| Analysis | Purpose | Replications |
|----------|---------|--------------|
| Power | Conditional probability of success at fixed effect size | 100/N |
| Assurance | Bayesian expected power over effect uncertainty | 100/N |
| Type I Error | False positive rate under null hypothesis | 500/N |

EXEC_SUMMARY

  # Trial Design Parameters
  cat >> "$REPORT_FILE" << 'TRIAL_PARAMS'

---

## Trial Design Parameters

### Co-Primary Outcomes

| Parameter | TMT B/A Ratio | MFIS |
|-----------|---------------|------|
| Full Name | Trail Making Test B/A | Modified Fatigue Impact Scale |
| Population Mean | 2.22 | 23.7 |
| Population SD | 1.07 | 21.1 |
| MCID | 0.5 | 10 |
| Range | [0.9, 5.0] | [0, 84] |
| Direction | Lower is better | Lower is better |

### Treatment Effects (Design Assumptions)

| Outcome | Treatment Effect | Residual SD |
|---------|------------------|-------------|
| TMT B/A | -0.15 (reduction) | 0.5 |
| MFIS | -5.0 points (reduction) | 8.0 |

**Outcome Correlation (ρ):** 0.2

### Decision Thresholds

| Decision | Criterion |
|----------|-----------|
| Efficacy (Success) | P(γ < 0 \| data) ≥ 0.95 for BOTH outcomes |
| Futility (Stop early) | P(γ < 0 \| data) < 0.10 for EITHER outcome |

### Randomization

- **Allocation Ratio:** 2:1 (Treatment:Control)
- **Sample Size Range:** 120 to 480 (increments of 60)

TRIAL_PARAMS

  # Statistical Model
  cat >> "$REPORT_FILE" << 'STAT_MODEL'

---

## Statistical Model

### Bivariate Normal Model

The analysis uses a Bayesian bivariate normal model with baseline adjustment:

```
y_tmt[i] ~ Normal(α_tmt + β_tmt * x_tmt[i] + γ_tmt * treat[i], σ_tmt)
y_mfis[i] ~ Normal(α_mfis + β_mfis * x_mfis[i] + γ_mfis * treat[i], σ_mfis)
```

Where:
- `y`: Follow-up outcome
- `x`: Baseline measurement (standardized)
- `treat`: Treatment indicator (1 = taurine, 0 = placebo)
- `γ`: Treatment effect parameter (negative = benefit)

### Prior Distributions

| Parameter | Prior | Rationale |
|-----------|-------|-----------|
| α (intercept) | Normal(0, 5) | Weakly informative |
| β (baseline) | Normal(1, 0.5) | Expected regression to mean |
| γ (treatment) | Normal(0, 2) | Skeptical, centered at null |
| σ (residual SD) | Half-Normal(0, 5) | Weakly informative |
| ρ (correlation) | LKJ(2) | Slight preference for independence |

### Inference

Stan MCMC sampling with:
- 4 parallel chains
- 1,000 warmup iterations
- 2,000 sampling iterations
- adapt_delta = 0.95
- max_treedepth = 12

STAT_MODEL

  # Simulation Configuration
  cat >> "$REPORT_FILE" << 'SIM_CONFIG'

---

## Simulation Configuration

### Power Analysis

- **Objective:** Estimate conditional power at fixed effect sizes
- **Effect Sizes:** TMT γ = -0.15, MFIS γ = -5.0
- **Replications:** 100 per sample size
- **Sample Sizes:** 120, 180, 240, 300, 360, 420, 480

### Assurance Analysis

- **Objective:** Estimate Bayesian assurance (expected power)
- **Design Prior:** Integrates uncertainty in effect size
  - TMT: Normal(-0.10, 0.05)
  - MFIS: Normal(-0.20, 0.10) on standardized scale
- **Replications:** 100 per sample size

### Type I Error Analysis

- **Objective:** Verify false positive rate under null hypothesis
- **True Effect:** γ = 0 for both outcomes
- **Replications:** 500 per sample size (higher precision needed)
- **Target:** Type I error ≤ 0.025 (one-sided)

SIM_CONFIG

  # Infrastructure
  cat >> "$REPORT_FILE" << 'INFRA'

---

## Infrastructure

### AWS ParallelCluster Configuration

| Component | Instance Type | Cost/Hour |
|-----------|---------------|-----------|
| Head Node | t3.large | $0.083 |
| Compute Nodes | c5.xlarge (4 vCPU, 8GB) | $0.170 |

**Compute Cluster:**
- Min nodes: 0 (auto-scales down)
- Max nodes: 10
- Slurm job scheduler

### Software Environment

| Component | Version |
|-----------|---------|
| R | 4.x |
| CmdStan | 2.37.0 |
| cmdstanr | Latest |
| Stan Model | coprimary_model_v4.stan |

### Parallelization Strategy

- **Job Arrays:** 7 parallel jobs (one per sample size)
- **Within Job:** 4 parallel MCMC chains
- **Memory:** 6 GB per job
- **CPU:** 4 cores per job

INFRA

  # Simulation Results Section - will be populated with actual data
  echo "" >> "$REPORT_FILE"
  echo "---" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  echo "## Simulation Results" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"

  # Power Results
  echo "### Power Analysis" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  if [ "$power_saved" -eq 7 ]; then
    echo "**Status:** COMPLETED" >> "$REPORT_FILE"
    if [ -n "${SIM_ELAPSED_SECONDS[power]}" ] && [ "${SIM_ELAPSED_SECONDS[power]}" -gt 0 ]; then
      echo "**Runtime:** $(format_duration ${SIM_ELAPSED_SECONDS[power]})" >> "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
    echo "| Sample Size | Result File | Status |" >> "$REPORT_FILE"
    echo "|-------------|-------------|--------|" >> "$REPORT_FILE"
    for n in 120 180 240 300 360 420 480; do
      echo "| $n | power_n${n}.rds | ✓ Saved |" >> "$REPORT_FILE"
    done
  else
    echo "**Status:** $power_saved/7 complete" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "| Sample Size | Status |" >> "$REPORT_FILE"
    echo "|-------------|--------|" >> "$REPORT_FILE"
    for n in 120 180 240 300 360 420 480; do
      if [ -f "/shared/taurinelc/data/cached_results/power_n${n}.rds" ]; then
        echo "| $n | ✓ Saved |" >> "$REPORT_FILE"
      else
        echo "| $n | Pending |" >> "$REPORT_FILE"
      fi
    done
  fi
  echo "" >> "$REPORT_FILE"

  # Assurance Results
  echo "### Assurance Analysis" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  if [ "$assurance_saved" -eq 7 ]; then
    echo "**Status:** COMPLETED" >> "$REPORT_FILE"
    if [ -n "${SIM_ELAPSED_SECONDS[assurance]}" ] && [ "${SIM_ELAPSED_SECONDS[assurance]}" -gt 0 ]; then
      echo "**Runtime:** $(format_duration ${SIM_ELAPSED_SECONDS[assurance]})" >> "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
    echo "| Sample Size | Result File | Status |" >> "$REPORT_FILE"
    echo "|-------------|-------------|--------|" >> "$REPORT_FILE"
    for n in 120 180 240 300 360 420 480; do
      echo "| $n | assurance_n${n}.rds | ✓ Saved |" >> "$REPORT_FILE"
    done
  else
    echo "**Status:** $assurance_saved/7 complete" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "| Sample Size | Status |" >> "$REPORT_FILE"
    echo "|-------------|--------|" >> "$REPORT_FILE"
    for n in 120 180 240 300 360 420 480; do
      if [ -f "/shared/taurinelc/data/cached_results/assurance_n${n}.rds" ]; then
        echo "| $n | ✓ Saved |" >> "$REPORT_FILE"
      else
        echo "| $n | Pending |" >> "$REPORT_FILE"
      fi
    done
  fi
  echo "" >> "$REPORT_FILE"

  # Type I Error Results
  echo "### Type I Error Analysis" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  if [ "$type1_saved" -eq 7 ]; then
    echo "**Status:** COMPLETED" >> "$REPORT_FILE"
    if [ -n "${SIM_ELAPSED_SECONDS[type1]}" ] && [ "${SIM_ELAPSED_SECONDS[type1]}" -gt 0 ]; then
      echo "**Runtime:** $(format_duration ${SIM_ELAPSED_SECONDS[type1]})" >> "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
    echo "| Sample Size | Result File | Status |" >> "$REPORT_FILE"
    echo "|-------------|-------------|--------|" >> "$REPORT_FILE"
    for n in 120 180 240 300 360 420 480; do
      echo "| $n | type1_n${n}.rds | ✓ Saved |" >> "$REPORT_FILE"
    done
  else
    echo "**Status:** $type1_saved/7 complete" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "| Sample Size | Status |" >> "$REPORT_FILE"
    echo "|-------------|--------|" >> "$REPORT_FILE"
    for n in 120 180 240 300 360 420 480; do
      if [ -f "/shared/taurinelc/data/cached_results/type1_n${n}.rds" ]; then
        echo "| $n | ✓ Saved |" >> "$REPORT_FILE"
      else
        echo "| $n | Pending |" >> "$REPORT_FILE"
      fi
    done
  fi
  echo "" >> "$REPORT_FILE"

  # Cost Summary
  echo "### Cost Summary" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  echo "| Category | Time | Cost (USD) |" >> "$REPORT_FILE"
  echo "|----------|------|------------|" >> "$REPORT_FILE"
  printf "| Completed | %s | \$%.2f |\n" "$(format_duration $total_completed_time)" $completed_compute_cost >> "$REPORT_FILE"
  if [ "$total_running_elapsed" -gt 0 ]; then
    printf "| Running | %s | \$%.2f |\n" "$(format_duration $total_running_elapsed)" $running_compute_cost >> "$REPORT_FILE"
  fi
  if [ "$total_not_started_time" -gt 0 ]; then
    printf "| Remaining (est.) | %s | \$%.2f |\n" "$(format_duration $total_not_started_time)" $not_started_compute_cost >> "$REPORT_FILE"
  fi
  printf "| **Total** | %s | **\$%.2f** |\n" "$(format_duration $total_project_time)" $total_cost >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"

  # Quality Assurance
  cat >> "$REPORT_FILE" << 'QA_SECTION'

---

## Quality Assurance

### Reproducibility

- **Random Seeds:** Unique prime-based seeds per array task
  - Power: Base 4231 + task_id × 1117
  - Assurance: Base 2234 + task_id × 1000
  - Type I Error: Base 5000 + task_id × 1000
- **Version Control:** Git repository with locked dependencies
- **Results Cache:** Individual .rds files per sample size

### MCMC Diagnostics

For each simulation replicate, the following diagnostics are checked:
- R-hat < 1.01 for all parameters
- Bulk ESS > 400
- Tail ESS > 400
- No divergent transitions
- No max treedepth warnings

### Data Quality

- Truncated normal distributions respect outcome bounds
- Baseline-adjusted means reflect target population
- 2:1 randomization maintained exactly

QA_SECTION

  # Appendix
  cat >> "$REPORT_FILE" << 'APPENDIX'

---

## Appendix: Technical Details

### File Structure

```
/shared/taurinelc/
├── R/
│   ├── parameters.R          # Trial parameters
│   ├── priors.R              # Two-prior framework
│   ├── simulate_data.R       # Data generation
│   ├── fit_model.R           # Stan model interface
│   ├── power_analysis.R      # Power/assurance functions
│   └── type1_error.R         # Type I error estimation
├── stan/
│   └── coprimary_model_v4.stan  # Bayesian model
├── cluster/
│   ├── slurm_power_array.sh     # Power job script
│   ├── slurm_assurance_array.sh # Assurance job script
│   ├── slurm_type1_array.sh     # Type I error job script
│   └── check_progress.sh        # This monitoring script
├── data/cached_results/
│   ├── power_n*.rds
│   ├── assurance_n*.rds
│   └── type1_n*.rds
└── logs/
    └── *.out, *.err           # SLURM job logs
```

### SLURM Job Configuration

```bash
#SBATCH --partition=compute
#SBATCH --array=1-7
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=6G
```

### Result File Format

Each .rds file contains:

**Power/Assurance:**
```r
list(
  n = sample_size,
  power/assurance = point_estimate,
  lower_ci = wilson_lower,
  upper_ci = wilson_upper,
  successes = count,
  n_valid = valid_reps,
  elapsed_mins = runtime
)
```

**Type I Error:**
```r
list(
  n = sample_size,
  type1_error = point_estimate,
  lower_ci = wilson_lower,
  upper_ci = wilson_upper,
  false_positives = count,
  n_valid = valid_reps,
  decision_threshold = 0.95
)
```

APPENDIX

  # Add report generation timestamp at end
  echo "" >> "$REPORT_FILE"
  echo "---" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  echo "*Report generated by check_progress.sh on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S %Z')*" >> "$REPORT_FILE"

  # Get cluster public IP address
  # Try SSH_CONNECTION first (contains the IP you connected to)
  if [ -n "$SSH_CONNECTION" ]; then
    CLUSTER_IP=$(echo "$SSH_CONNECTION" | awk '{print $3}')
  fi
  # Try AWS metadata with IMDSv2 token
  if [ -z "$CLUSTER_IP" ]; then
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
    if [ -n "$TOKEN" ]; then
      CLUSTER_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    fi
  fi
  # Fallback to private IP
  if [ -z "$CLUSTER_IP" ]; then
    CLUSTER_IP=$(hostname -I | awk '{print $1}')
  fi

  echo ""
  echo "Report saved to: $REPORT_FILE"
  echo ""
  echo "To copy to local machine:"
  echo "  scp -i ~/.ssh/pcluster-key.pem ubuntu@${CLUSTER_IP}:${REPORT_FILE} ."
  echo ""
fi

echo ""
echo "===================================================================="
