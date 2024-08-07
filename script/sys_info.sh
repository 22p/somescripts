#!/bin/bash

# 获取系统负载
get_load() {
  cpucount=$(grep -c processor /proc/cpuinfo)
  awk -v cpucount="$cpucount" '{
      load = ($1 / cpucount) * 100
      color = (load > 150) ? "\033[0;31m" : ((load > 100) ? "\033[0;33m" : "\033[0;32m")
      printf "%-13s%s%s %s %s (%s%%)\033[0m\n", "System load", color, $1, $2, $3, load
    }' /proc/loadavg
}

# 获取系统运行时间
get_uptime_info() {
  awk -F. '{
    days = int($1 / 86400)
    hours = int(($1 % 86400) / 3600)
    minutes = int(($1 % 3600) / 60)
    color = (days > 30) ? "\033[0;33m" : (days >= 15) ? "\033[0;36m" : "\033[0;32m"
    printf "%-13s%s%s days, %s hours, %s minutes\033[0m\n", "Up time", color, days, hours, minutes
  }' /proc/uptime
}

# 获取本地用户数量
get_login_users() {
  printf "%-13s\033[0;32m$(who | wc -l)\033[0m\n" "Login users"
}

# 获取内存使用情况
get_mem_info() {
  free -m | awk '
    /Mem:/ {
      percent = ($3 * 100) / $2
      color = (percent > 90) ? "\033[0;31m" : ((percent > 80) ? "\033[0;33m" : "\033[0;32m")
      printf "%-13s%s%sMiB\033[0m/%sMiB (%.2f%%)\n", "RAM usage", color, $3, $2, percent
    }'
}

# 获取磁盘使用情况
get_disk_info() {
df -h | awk '
  /^\/dev/{
    use = substr($5, 1, length($5)-1)
    color = (use > 90) ? "\033[0;31m" : ((use > 80) ? "\033[0;33m" : "\033[0;32m")
    printf "%-13s%s%s/\033[0m%s (%s)\n", $6, color, $3, $2, $5
}'
}

# 获取CPU温度
get_cpu_temp() {
  awk '{
  temp = $1 / 1000
  color = (temp > 80) ? "\033[0;31m" : (temp >= 60) ? "\033[0;33m" : "\033[0;32m"
  printf "%-13s%s%s°C\033[0m\n", "CPU temp", color, temp
  }' /sys/devices/platform/coretemp.*/hwmon/hwmon*/temp1_input 2>/dev/null
}

convert_bytes() {
  local bytes=$1
  if [ $bytes -lt $((1 << 30)) ]; then
    echo $(awk -v bytes=$bytes 'BEGIN {printf "%.2fMiB", bytes / (2^20)}')
  else
    echo $(awk -v bytes=$bytes 'BEGIN {printf "%.2fGiB", bytes / (2^30)}')
  fi
}

# 获取接口信息
get_iface_stats() {
  for iface in $(ls /sys/class/net/ | grep -Ev "lo|bonding_masters"); do
    rx_bytes=$(cat /sys/class/net/$iface/statistics/rx_bytes)
    tx_bytes=$(cat /sys/class/net/$iface/statistics/tx_bytes)

    interfaces+=($iface)
    rx_data+=($(convert_bytes $rx_bytes))
    tx_data+=($(convert_bytes $tx_bytes))
  done

  printf "Interface %s\n" "${interfaces[*]}" | xargs printf "%-13s"
  echo ""
  printf "TX %s\n" "${tx_data[*]}" | xargs printf "%-13s"
  echo ""
  printf "RX %s\n" "${rx_data[*]}" | xargs printf "%-13s"
  echo ""
}

# 获取IP地址
get_ip() {
  local ip_address
  local ip6_address

  ip_address=$(ip -4 addr show scope global 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1 | xargs)

  printf "%-13s\033[0;35m%s\033[0m\n" "IPv4" "$ip_address"

  ip6_address=$(ip -6 addr show scope global 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1 | xargs)

  printf "%-13s\033[0;35m%s\033[0m\n" "IPv6" "$ip6_address"
}

line1="---------------------------------"
echo -e "\nSystem Information:"
echo $line1
get_load
get_uptime_info
get_login_users
get_mem_info
get_cpu_temp
echo -e "\nMount Point Information:"
echo $line1
get_disk_info
echo -e "\nNetwork Information:"
echo $line1
get_iface_stats
get_ip
