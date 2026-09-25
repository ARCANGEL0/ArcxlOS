#!/bin/sh






sysctl -w net.ipv4.tcp_ecn=0

sysctl -w net.ipv4.tcp_window_scaling=1

sysctl -w net.ipv4.tcp_rmem='8192 87380 16777216'
sysctl -w net.ipv4.tcp_wmem='8192 65536 16777216'

sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216

sysctl -w net.core.netdev_max_backlog=16384
sysctl -w net.core.netdev_budget=50000
sysctl -w net.core.netdev_budget_usecs=5000
sysctl -w net.core.dev_weight=64

sysctl -w net.core.somaxconn=32768

sysctl -w net.core.optmem_max=65535

sysctl -w net.ipv4.tcp_max_tw_buckets=1440000

sysctl -w net.ipv4.tcp_tw_reuse=1

sysctl -w net.ipv4.tcp_max_orphans=16384
sysctl -w net.ipv4.tcp_orphan_retries=0

sysctl -w net.ipv4.tcp_no_metrics_save=1
sysctl -w net.ipv4.tcp_moderate_rcvbuf=1

sysctl -w net.unix.max_dgram_qlen=50

sysctl -w net.ipv4.neigh.default.gc_thresh3=2048

sysctl -w net.ipv4.neigh.default.gc_thresh2=1024

sysctl -w net.ipv4.neigh.default.gc_thresh1=32

sysctl -w net.ipv4.neigh.default.gc_interval=30

sysctl -w net.ipv4.neigh.default.proxy_qlen=96
sysctl -w net.ipv4.neigh.default.unres_qlen=6

sysctl -w net.ipv4.tcp_ecn=1
sysctl -w net.ipv4.tcp_reordering=3

sysctl -w net.ipv4.tcp_retries2=15
sysctl -w net.ipv4.tcp_retries1=3

sysctl -w net.ipv4.tcp_slow_start_after_idle=0

sysctl -w net.ipv4.tcp_fastopen=3

sysctl -w net.ipv4.route.flush=1
sysctl -w net.ipv6.route.flush=1

