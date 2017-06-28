+++
date = "2017-05-13T18:02:49+01:00"
title = "Schedule multiple bash script with cron"
image = "/img/scheduler.jpg"
imagemin = "/img/scheduler-min.jpg"
comments = true
description = "A simple scheduler written in bash to postpone script execution"
tags = ["bash", "job scheduling", "devops"]
categories = ["tutorials"]
+++


![Back to the future timer](/img/scheduler.jpg)

In several occasions you may need to postpone the execution of some web requests, for performance reasons, timelines in response or resource consumption. In few PHP projects I found very useful the script below. It uses a scripts directory to read all the sh files from. Each file in the scripts directory gets moved to a running directory before execution. At the end of the execution it checks the return value and based on the result moves the sh file to the completed directory or the failed directory. I usually configure cron to schedule this script at intervals or during low trafic hours.

<pre>
<code class="bash">#!/usr/bin/env bash

echo $$
PID_FILE="scheduler.pid"

if [[ -e ${PID_FILE} ]]; then
    kill -9 $(cat $PID_FILE)
fi

echo $$ > $PID_FILE

SCRIPT_DIR=${1:-"./scripts"} #default scripts dir is ./scripts
LOG_DIR=${2:-"./logs"} #default log dir is ./logs
DONE_DIR=${3:-"./completed"} #default done dir is ./completed
FAILED_PREFIX=${4:-"failed_"}
RUNNING_DIR=${5:-"./running"} #default running dir is ./running
COUNTER=0

mkdir -p $SCRIPT_DIR
mkdir -p $LOG_DIR
mkdir -p $DONE_DIR
mkdir -p $RUNNING_DIR

FILES=$(find $SCRIPT_DIR -type f -iname "*.sh")

for f in $FILES
do
     let COUNTER=COUNTER+1
     log_file=${f%.sh}_$(date +%Y%m%d_%H%M%S).log
     mv $f ${RUNNING_DIR}
     running_file=${RUNNING_DIR}${f:${#SCRIPT_DIR}}
     source $running_file > ${LOG_DIR}${log_file:${#SCRIPT_DIR}}
     if [[ $? -eq 0 ]]; then
        echo moving script to ${DONE_DIR}
        mv $running_file ${DONE_DIR}
     elif [[ $(basename "$f") != *"${FAILED_PREFIX}"* ]]; then
        echo ERROR
        filename_only=$(basename "$running_file")
        mv $running_file ${SCRIPT_DIR}/${FAILED_PREFIX}${filename_only}
     fi
done


if [ $COUNTER -eq 0 ]; then
    echo NO FILES TO RUN
else
    echo $COUNTER FILES EXECUTED
fi

rm -f $PID_FILE
</code></pre>

