#!/bin/bash
trap : SIGTERM SIGINT

function abspath() {
    # generate absolute path from relative path
    # $1     : relative filename
    # return : absolute path
    if [ -d "$1" ]; then
        # dir
        (cd "$1"; pwd)
    elif [ -f "$1" ]; then
        # file
        if [[ $1 = /* ]]; then
            echo "$1"
        elif [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/${1##*/}"
        else
            echo "$(pwd)/$1"
        fi
    fi
}

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 LAUNCH_FILE" >&2
  exit 1
fi

roscore &
ROSCORE_PID=$!
sleep 1

rviz -d ../config/vins_rviz_config.rviz &
RVIZ_PID=$!

VINS_MONO_DIR=$(abspath "..")

docker run \
  -it \
  --rm \
  --net=host \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e DISPLAY \
  -e QT_X11_NO_MITSHM=1 \
  -v ${VINS_MONO_DIR}:/root/catkin_ws/src/VINS-Mono/ \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --runtime=nvidia \
  -e NVIDIA_VISIBLE_DEVICES=0 \
  ros:vins-mono \
  /bin/bash -c \
  "cd /root/catkin_ws/; \
  catkin config \
        --env-cache \
        --extend /opt/ros/$ROS_DISTRO \
       --cmake-args \
         -DCMAKE_BUILD_TYPE=Release; \
     catkin build; \
     source devel/setup.bash; \
     roslaunch vins_estimator ${1}"

wait $ROSCORE_PID
wait $RVIZ_PID

if [[ $? -gt 128 ]]
then
    kill $ROSCORE_PID
    kill $RVIZ_PID
fi
