#!/bin/bash
#
#  Copyright 2011 National ICT Australia Limited
#
#  Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#Script to autorun everything by calling install, deploy, run and data 
#collect scripts. Feel free to disable some scripts if they are not 
#necessary in your experiments.
#
#
#########################################################
#
#The script uses root + ssh key to access EC2 instances.
#So always run scripts in an experimental environment.
#Make sure to check each script for NOTE, in case of any
#conflicts to your system.
#
#########################################################
#
#NOTE:
#1. It is suggested to refer to Cloudstone/Faban for configuration details
#   http://www.opensparc.net/sunsource/faban/www/
#2. The MYSQL_INSTANCE_PAUSE is used for CloudDB AutoAdmin, it is suggested 
#   to kept it commented or empty if you only need to run our benchmark.
#3. 7-zip is pre-required for the data archieve.
#4. Edit interval-write value at the end of run.xml.OlioDriver.template file
#   to have customized replication heartbeat.
#5. To integerated with CloudDB AutoAdmin, you have to enable 
#   i.  MYSQL_INSTANCE_PAUSE in this file
#   ii. Replace JDBC driver in the middle, and PROXY_ADDRESS_PORT at the 
#       beginning, of the deploy.template.sh
#   iii.Variable workload can be enabled in deploy.template.sh, with 
#       specification in load.txt.
#       http://www.opensparc.net/sunsource/faban/www/1.0/docs/howdoi/loadvariation.html
#   iv. Match replication heartbeat with heartbeat interval in CloudDB 
#       Autoadmin configure.
#   

LOCATION=`pwd`

check_errs()
{
  # Function. Parameter 1 is the return code
  # Para. 2 is text to display on failure.
  if [ "${1}" -ne "0" ]; then
    echo "ERROR # ${1} : ${2}"
    # as a bonus, make our script exit with the right error code.
    exit ${1}
  fi
}

FABAN_INSTANCE=("FABAN1.us-west-1.compute.amazonaws.com" \
    			"FABAN2.us-west-1.compute.amazonaws.com")
MYSQL_INSTANCE_RUN=("MYSQL1.us-west-1.compute.amazonaws.com" \
	                "MYSQL2.us-west-1.compute.amazonaws.com")
MYSQL_INSTANCE_PAUSE=("MYSQL3.us-west-1.compute.amazonaws.com")
NUM_OF_USERS=("15" "30" "45" "60" "75" "85" "95" "110" "125" "140" "155")
ARCHIVE_PATH="Downloads"
STEP=1

echo "Experiments start at `date`"
rm ~/.ssh/known_hosts > /dev/null 2>&1

faban_instance_all=${FABAN_INSTANCE[0]}
for ((k=1; k<${#FABAN_INSTANCE[*]}; k++)) do
	faban_instance_all=$faban_instance_all" "${FABAN_INSTANCE[$k]}
done
mysql_instance_all=${MYSQL_INSTANCE_RUN[0]}
for ((k=1; k<${#MYSQL_INSTANCE_RUN[*]}; k++)) do
	mysql_instance_all=$mysql_instance_all" "${MYSQL_INSTANCE_RUN[$k]}
done
mysql_instance_pause=${MYSQL_INSTANCE_PAUSE[0]}
mysql_instance_all=$mysql_instance_all" "${MYSQL_INSTANCE_PAUSE[0]}
for ((k=1; k<${#MYSQL_INSTANCE_PAUSE[*]}; k++)) do
	mysql_instance_all=$mysql_instance_all" "${MYSQL_INSTANCE_PAUSE[$k]}
	mysql_instance_pause=$mysql_instance_pause" "${MYSQL_INSTANCE_PAUSE[$k]}
done

cd "$LOCATION/install" && ./install.template.sh "$faban_instance_all" "$mysql_instance_all" > /dev/null 2>&1
cd "$LOCATION/update" && ./update.template.sh "$faban_instance_all" "$mysql_instance_all" > /dev/null 2>&1
check_errs $? "Install instances failed."

for ((k=${#MYSQL_INSTANCE_RUN[*]}; k>1; k=$[$k-$STEP])) do
	mysql_instance_run=${MYSQL_INSTANCE_RUN[0]}
	for ((m=1; m < k; m++)) do
		mysql_instance_run=$mysql_instance_run" "${MYSQL_INSTANCE_RUN[$m]}
	done
	echo "Installing Faban and MySQL instances for running ${#NUM_OF_USERS[*]} benchmarks ..."
	for ((i=0; i < ${#NUM_OF_USERS[*]}; i++)) do
		echo "Running Benchmark ($[i+1]/${#NUM_OF_USERS[*]}) ..."
		# Deploy instances
		echo ".. (1/3) Deploy Faban and MySQL instances for ${NUM_OF_USERS[$i]} concurrent users"
		cd "$LOCATION/deploy" && ./deploy.template.sh "$faban_instance_all" "$mysql_instance_run" "$mysql_instance_pause" ${NUM_OF_USERS[$i]}
		check_errs $? "Deploy instances failed."
		# Start test from command line
		cd "$LOCATION"
		task_name=`ssh root@${FABAN_INSTANCE[0]} "export JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk \
			&& ulimit -Hn 32768 \
			&& ulimit -Sn 32768 \
			&& ~/faban/bin/fabancli submit OlioDriver dbadmin ~/faban/config/profiles/dbadmin/run.xml.OlioDriver"`
		status=`ssh root@${FABAN_INSTANCE[0]} "export JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk \
			&& ~/faban/bin/fabancli status $task_name"`
		echo ".. (2/3) Start a new benchmark as $task_name, in the status of $status"
		while [ "$status" == "STARTED" ]; do
			for ((t=0; t<30; t++)) do
				printf ".";
				sleep 1;
			done
			status=`ssh root@${FABAN_INSTANCE[0]} "export JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk \
				&& ~/faban/bin/fabancli status $task_name"`
		done
		printf "\n";
		sleep 10
		echo ".. (3/3) Collect result set for benchmark $task_name"
		# Collecting data from instances
		mysql_instance_run_a=($mysql_instance_run)
		mysql_instance_s=`echo ${#mysql_instance_run_a[*]} 1 | awk '{ printf("%d",($1-$2))}'`
		cd "$LOCATION/post" && ./resultset.template.sh "${FABAN_INSTANCE[0]}" "$mysql_instance_run" $task_name $ARCHIVE_PATH > /dev/null 2>&1
		archive="OlioDriver_${mysql_instance_s}Database_${NUM_OF_USERS[$i]}User"
		idx=1
		# Rename file if it existed, not working at the moment
		while [ -d ~/$ARCHIVE_PATH/$archive.7z ]; do
			archive="OlioDriver_${mysql_instance_s}Database_${NUM_OF_USERS[$i]}User_$idx"
			idx=$[$idx+1]
		done
		mv ~/$ARCHIVE_PATH/$task_name ~/$ARCHIVE_PATH/$archive
		7za a -t7z ~/$ARCHIVE_PATH/$archive.7z ~/$ARCHIVE_PATH/$archive
		rm -fr ~/$ARCHIVE_PATH/$archive
	done
done
echo "Experiments end at `date`"