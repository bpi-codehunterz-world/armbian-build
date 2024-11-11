#!/bin/bash
### BEGIN INIT INFO
# Provides:          set_led_trigger
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Set LED triggers at boot
# Description:       This script sets the LED triggers at boot time
### END INIT INFO

echo "heartbeat" > /sys/class/leds/bananapi:green:user/trigger
echo "cpu0" > /sys/class/leds/bananapi:red:pwr/trigger
