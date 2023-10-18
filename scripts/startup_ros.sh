# ******************************************************************************************
# ******************************************************************************************
# ******************************************************************************************
# ******************************************************************************************

echo "STARTING TIME: $(date)"            >> /tmp/ros_startup.log

# Default input value
DEFAULT_CHECK_DURATION=60
DEFAULT_ROS_IP=192.168.26.5
DEFAULT_NETWORK_INTERFACE=wlp0s20f3

INPUT_NETWORK_INTERFACE="$1"
INPUT_ROS_IP="$2"
INPUT_CHECK_DURATION="$3"

# # Check if the user gave the network interface input
# if [ -z "$1" ]; then
#     echo "Usage: $0 <network_interface> <ros_ip>"
#     exit 1
# fi

# # Check if the user gave the ROS_IP 
# if [ -z "$2" ]; then
#     echo "Usage: $2 <network_interface> <ros_ip>"
#     exit 1
# fi

# Network interface check duration
CHECK_DURATION=${INPUT_CHECK_DURATION:-$DEFAULT_CHECK_DURATION}
ROS_IP=${INPUT_ROS_IP:-$DEFAULT_ROS_IP}
NETWORK_INTERFACE=${INPUT_NETWORK_INTERFACE:-$DEFAULT_NETWORK_INTERFACE}

# Check start instant
START=$(date +%s)
INTERFACE_STATUS=false

# Check for 10 seconds if the network interface gets an IP equal to the one given as input to the script (that will be ROS_IP) 
while [ $(($(date +%s) - $START)) -lt $CHECK_DURATION ]; do
    IP=$(ip -4 addr show "$NETWORK_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    if [ "$IP" == "$ROS_IP" ]; then
        echo "IP address is equal to \$ROS_IP."
        export ROS_IP=$ROS_IP
        INTERFACE_STATUS=true
        # echo "Network interface found in: $(($(date +%s) - $START)) sec"
        break
        
    else
        # echo "Waiting $INTERFACE interface... countdown: $((CHECK_DURATION - ($(date +%s) - $START))) sec"
        INTERFACE_STATUS=false
    fi
    sleep 1

done

echo "ROS_NETWORK_INTERFACE $NETWORK_INTERFACE found in: $(($(date +%s) - $START))"      >> /tmp/ros_startup.log
echo "ROS_IP: $ROS_IP"                                                                   >> /tmp/ros_startup.log
echo "INTERFACE_STATUS: $INTERFACE_STATUS"                                               >> /tmp/ros_startup.log

# ******************************************************************************************
# ******************************************************************************************
# ******************************************************************************************
# ******************************************************************************************