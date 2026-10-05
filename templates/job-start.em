@#
@# Author: Mike Purvis <mpurvis@clearpathrobotics.com>
@#         Copyright (c) 2013-2014, Clearpath Robotics, Inc.
@#
@# Redistribution and use in source and binary forms, with or without
@# modification, are permitted provided that the following conditions are met:
@#    * Redistributions of source code must retain the above copyright
@#       notice, this list of conditions and the following disclaimer.
@#    * Redistributions in binary form must reproduce the above copyright
@#       notice, this list of conditions and the following disclaimer in the
@#       documentation and/or other materials provided with the distribution.
@#    * Neither the name of Clearpath Robotics, Inc. nor the
@#       names of its contributors may be used to endorse or promote products
@#       derived from this software without specific prior written permission.
@#
@# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
@# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
@# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
@# DISCLAIMED. IN NO EVENT SHALL CLEARPATH ROBOTICS, INC. BE LIABLE FOR ANY
@# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
@# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
@# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
@# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
@# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
@# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
@#
@# Please send comments, questions, or patches to code@clearpathrobotics.com
#!/bin/bash
# THIS IS A GENERATED FILE, NOT RECOMMENDED TO EDIT.

function log() {
  logger -s -p user.$1 ${@@:2}
}

log info "@(name): Using workspace setup file @(workspace_setup)"
source @(workspace_setup)
JOB_FOLDER=@(job_path)

log_path="@(log_path)"
if [[ ! -d $log_path ]]; then
  CREATED_LOGDIR=true
  trap 'CREATED_LOGDIR=false' ERR
    log warn "@(name): The log directory you specified \"$log_path\" does not exist. Attempting to create."
    mkdir -p $log_path 2>/dev/null
    chown @(user):@(user) $log_path 2>/dev/null
    chmod ug+wr $log_path 2>/dev/null
  trap - ERR
  # if log_path could not be created, default to tmp
  if [[ $CREATED_LOGDIR == false ]]; then
    log warn "@(name): The log directory you specified \"$log_path\" cannot be created. Defaulting to \"/tmp\"!"
    log_path="/tmp"
  fi
fi

# ******************************************************************************************
# ******************************************************************************************
# ******************************************************************************************
# ******************************************************************************************

echo "STARTING TIME: $(date)"            >> /tmp/ros_startup.log

# Default input value
DEFAULT_CHECK_DURATION=60
DEFAULT_ROS_IP=192.168.26.131
DEFAULT_NETWORK_INTERFACE=enx207bd287d64d

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

export ROS_HOME=${ROS_HOME:=$(echo ~@(user))/.ros}
export ROS_LOG_DIR=$log_path

log info "@(name): Launching ROS_HOSTNAME=$ROS_HOSTNAME, ROS_IP=$ROS_IP, ROS_MASTER_URI=$ROS_MASTER_URI, ROS_HOME=$ROS_HOME, ROS_LOG_DIR=$log_path"

# If xacro files are present in job folder, generate and expand an amalgamated urdf.
XACRO_FILENAME=$log_path/@(name).xacro
XACRO_ROBOT_NAME=$(echo "@(name)" | cut -d- -f1)
rosrun robot_upstart mkxacro $JOB_FOLDER $XACRO_ROBOT_NAME > $XACRO_FILENAME
if [[ "$?" == "0" ]]; then
  URDF_FILENAME=$log_path/@(name).urdf
  rosrun xacro xacro $XACRO_FILENAME -o $URDF_FILENAME
  if [[ "$?" == "0" ]]; then
    log info "@(name): Generated URDF: $URDF_FILENAME"
  else
    log warn "@(name): URDF macro expansion failure. Robot description will not function."
  fi
  export ROBOT_URDF_FILENAME=$URDF_FILENAME
fi

# Assemble amalgamated launchfile.
LAUNCH_FILENAME=$log_path/@(name).launch
rosrun robot_upstart mklaunch $JOB_FOLDER > $LAUNCH_FILENAME
if [[ "$?" != "0" ]]; then
  log err "@(name): Unable to generate amalgamated launchfile."
  exit 1
fi
log info "@(name): Generated launchfile: $LAUNCH_FILENAME"

# Warn and exit if setpriv is missing from the system.
which setpriv > /dev/null
if [ "$?" != "0" ]; then
  log err "@(name): Can't launch as unprivileged user without setpriv. Please install the setpriv package."
  exit 1
fi

# Punch it.
setpriv --reuid @(user) --regid @(user) --init-groups roslaunch $LAUNCH_FILENAME @(roslaunch_wait?'--wait ')&
PID=$!

log info "@(name): Started roslaunch as background process, PID $PID, ROS_LOG_DIR=$ROS_LOG_DIR"
echo "$PID" > $log_path/@(name).pid

wait "$PID"
