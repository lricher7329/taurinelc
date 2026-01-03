#!/bin/bash
# check_progress.sh
# Monitor progress of power analysis job array with time and cost estimates
# Run from head node: bash /shared/taurinelc/cluster/check_progress.sh

# Cost per hour (USD) - update these if instance types change
HEAD_NODE_COST=0.083    # t3.large
COMPUTE_NODE_COST=0.17  # c5.xlarge

echo "=== Power Analysis Job Array Progress ==="
echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Show queue status and get running job info
echo "Queue Status:"
queue_output=$(/opt/slurm/bin/squeue 2>/dev/null || squeue)
echo "$queue_output"
echo ""

# Count running jobs and get elapsed time
running_jobs=$(echo "$queue_output" | grep -c "  R  " || echo 0)
# Extract max elapsed time from running jobs (format: M:SS or H:MM:SS)
max_elapsed=$(echo "$queue_output" | grep "  R  " | awk '{print $6}' | sort -t: -k1,1nr -k2,2nr | head -1)

# Count completed simulations per node and calculate totals
echo "Completed Simulations per Node:"
total_completed=0
total_remaining=0
declare -a node_counts
declare -a node_remaining

for i in 1 2 3 4 5 6 7; do
  n=$((120 + (i-1)*60))
  logfile=$(ls -t /shared/taurinelc/logs/power_n${i}_*.out 2>/dev/null | head -1)
  if [ -n "$logfile" ]; then
    count=$(grep -c 'All 4 chains finished' "$logfile" 2>/dev/null || echo 0)
    remaining=$((100 - count))
    node_counts[$i]=$count
    node_remaining[$i]=$remaining
    total_completed=$((total_completed + count))
    total_remaining=$((total_remaining + remaining))

    # Calculate percentage
    pct=$((count * 100 / 100))
    bar=""
    for j in $(seq 1 10); do
      if [ $j -le $((pct / 10)) ]; then
        bar="${bar}#"
      else
        bar="${bar}-"
      fi
    done
    echo "  Node $i (N=$n): $count/100 [$bar] ${pct}%"
  else
    node_counts[$i]=0
    node_remaining[$i]=100
    total_remaining=$((total_remaining + 100))
    echo "  Node $i (N=$n): No log file yet [----------] 0%"
  fi
done

echo ""
echo "Overall Progress: $total_completed/700 ($((total_completed * 100 / 700))%)"
echo ""

# Time estimates
echo "=== Time Estimates ==="

# Parse elapsed time to seconds
parse_time_to_seconds() {
  local time_str=$1
  local seconds=0

  if [[ "$time_str" =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
    # H:MM:SS format
    seconds=$((${BASH_REMATCH[1]} * 3600 + ${BASH_REMATCH[2]} * 60 + ${BASH_REMATCH[3]}))
  elif [[ "$time_str" =~ ^([0-9]+):([0-9]+)$ ]]; then
    # M:SS format
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

if [ -n "$max_elapsed" ] && [ "$total_completed" -gt 0 ]; then
  elapsed_seconds=$(parse_time_to_seconds "$max_elapsed")

  # Calculate rate (simulations per second across all nodes)
  rate=$(echo "scale=4; $total_completed / $elapsed_seconds" | bc)

  # Estimate time remaining based on slowest node (N=480)
  # N=480 takes ~4x longer than N=120, so estimate based on that
  if [ "$total_remaining" -gt 0 ]; then
    # Get completion count for slowest node (node 7, N=480)
    slowest_completed=${node_counts[7]:-0}
    slowest_remaining=${node_remaining[7]:-100}

    if [ "$slowest_completed" -gt 0 ]; then
      # Estimate based on slowest node's rate
      slowest_rate=$(echo "scale=4; $slowest_completed / $elapsed_seconds" | bc)
      remaining_seconds=$(echo "scale=0; $slowest_remaining / $slowest_rate" | bc 2>/dev/null || echo 0)

      echo "Elapsed time: $(format_duration $elapsed_seconds)"
      echo "Avg rate: $(printf '%.2f' $rate) sims/sec (all nodes)"
      echo "Estimated time remaining: $(format_duration $remaining_seconds)"
      # Show completion time in UTC with clear label
      completion_utc=$(date -u -d "+${remaining_seconds} seconds" '+%H:%M:%S UTC' 2>/dev/null || date -u -v+${remaining_seconds}S '+%H:%M:%S UTC' 2>/dev/null || echo 'N/A')
      echo "Estimated completion: $completion_utc (in $(format_duration $remaining_seconds))"
    else
      echo "Elapsed time: $(format_duration $elapsed_seconds)"
      echo "Waiting for slowest node (N=480) to complete first simulation..."
    fi
  else
    echo "Elapsed time: $(format_duration $elapsed_seconds)"
    echo "All simulations complete!"
  fi
else
  echo "Waiting for jobs to start..."
fi

echo ""

# Cost estimates
echo "=== Cost Estimates ==="

# Get job start time from first log file
first_log=$(ls -t /shared/taurinelc/logs/power_n*_*.out 2>/dev/null | tail -1)
if [ -n "$first_log" ] && [ -n "$max_elapsed" ]; then
  elapsed_seconds=$(parse_time_to_seconds "$max_elapsed")
  elapsed_hours=$(echo "scale=4; $elapsed_seconds / 3600" | bc)

  # Current cost (running nodes + head node)
  compute_cost=$(echo "scale=4; $running_jobs * $COMPUTE_NODE_COST * $elapsed_hours" | bc)
  head_cost=$(echo "scale=4; $HEAD_NODE_COST * $elapsed_hours" | bc)
  current_total=$(echo "scale=4; $compute_cost + $head_cost" | bc)

  printf "Current compute cost: \$%.4f (%d nodes x \$%.3f/hr x %.2f hrs)\n" $compute_cost $running_jobs $COMPUTE_NODE_COST $elapsed_hours
  printf "Current head node cost: \$%.4f\n" $head_cost
  printf "Current total: \$%.4f\n" $current_total

  # Projected total cost (if we have time estimates)
  if [ "$total_completed" -gt 0 ] && [ "$total_remaining" -gt 0 ]; then
    slowest_completed=${node_counts[7]:-0}
    slowest_remaining=${node_remaining[7]:-100}

    if [ "$slowest_completed" -gt 0 ]; then
      slowest_rate=$(echo "scale=4; $slowest_completed / $elapsed_seconds" | bc)
      remaining_seconds=$(echo "scale=0; $slowest_remaining / $slowest_rate" | bc 2>/dev/null || echo 0)
      total_seconds=$((elapsed_seconds + remaining_seconds))
      total_hours=$(echo "scale=4; $total_seconds / 3600" | bc)

      # Assume 7 compute nodes for full duration (worst case)
      projected_compute=$(echo "scale=4; 7 * $COMPUTE_NODE_COST * $total_hours" | bc)
      projected_head=$(echo "scale=4; $HEAD_NODE_COST * $total_hours" | bc)
      projected_total=$(echo "scale=4; $projected_compute + $projected_head" | bc)

      echo ""
      printf "Projected total cost: \$%.4f (estimated)\n" $projected_total
    fi
  fi
else
  echo "No jobs running yet - cost will accrue once jobs start"
  echo "Head node: \$${HEAD_NODE_COST}/hr"
  echo "Compute nodes: \$${COMPUTE_NODE_COST}/hr each (7 nodes for job array)"
fi

echo ""

# Check for completed results files
echo "=== Saved Results ==="
completed_count=0
for i in 1 2 3 4 5 6 7; do
  n=$((120 + (i-1)*60))
  if [ -f "/shared/taurinelc/data/cached_results/power_n${n}.rds" ]; then
    echo "  N=$n: COMPLETE"
    completed_count=$((completed_count + 1))
  else
    echo "  N=$n: pending"
  fi
done

echo ""
if [ $completed_count -eq 7 ]; then
  echo "All results saved! Run: Rscript combine_power_results.R"
elif [ $completed_count -gt 0 ]; then
  echo "$completed_count/7 result files saved. Waiting for remaining jobs..."
fi

echo ""
echo "=== End Progress Report ==="
