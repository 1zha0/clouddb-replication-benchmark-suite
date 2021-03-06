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
#Script to deploy and config MySQL and Faban with specified workloads

if [ "${#}" -lt "7" ]; then
  echo "This script takes addresses of Faban and MySQL instances, "
  echo "database user name and password, as well as number of "
  echo "concurrent users to deploy the test environment."
  echo ""
  echo "Usage:"
  echo "   ${0} [Faban] [DATA_FORMAT] [MySQL Running] [MySQL Paused] [Num_User] [DATABASE_USER] [DATABASE_PASSWORD]"
  exit 0
fi

DATA_FORMAT=${1}
FABAN_INSTANCE="${2}"
MYSQL_INSTANCE_RUN="${3}"
MYSQL_INSTANCE_PAUSE="${4}"
NUM_OF_USER=${5}
NUM_OF_SCALE=${5}
NUM_OF_POOL_SIZE=-1

DATABASE_USER=${6}
DATABASE_PASSWORD=${7}

# The WRITE_INTERVAL defines the frequency of updating the heartbeats table 
# in milliseconds unit
WRITE_INTERVAL=1000
# The READ_INTERVAL was designed as a frequency of reading the heartbeats table 
# results in milliseconds unit, but since we always read the table at the end 
# of experiment, this variable is abandoned and replaced by defining the choices 
# of MySQL time/date function. If READ_INTERVAL is a positive value, we use a 
# customized microsecond-resolution time/date function. If it is negative, then
# we use the built-in second-resolution time/date function.
READ_INTERVAL=1000

# Define the proxy and address if database is connected via load balancer, you must start
# a proxy (e.g. MySQL Proxy) before specifying this variable.
# After specifying PROXY_ADDRESS_PORT, you also need to modify script snippet in 
# deploy_master_faban function
PROXY_ADDRESS_PORT="FABAN-PROXY.us-west-1.compute.amazonaws.com:PORT"

# This variable is used to enable variable loads, once this value is set to true.
# Please make sure that a load.txt file is configured in this folder and also ensure
# that the scale of the run matches the largest thread count in the load variation file,
# and also the total time of the load variation matches the steady state time of the run
# More details can be found in 
# http://www.opensparc.net/sunsource/faban/www/1.0/docs/howdoi/loadvariation.html
VARIABLE_LOAD=false

deploy_master_faban()
{
  # Prepare profile for Faban master
  num_host_list=0
  if [ "$DATA_FORMAT" == "raw" ]; then
	for mysql in $MYSQL_INSTANCE_RUN; do
	  db_host_list=$db_host_list"$mysql "
	  num_host_list=$[$num_host_list+1]
	done
	for mysql in $MYSQL_INSTANCE_PAUSE; do
	  db_host_list=$db_host_list"$mysql "
	  num_host_list=$[$num_host_list+1]
	done
	db_host_list=`echo $db_host_list | sed -e 's/,$//'`
  else
	db_host_list=" "
  fi


  for mysql in $MYSQL_INSTANCE_RUN; do
    db_serv_list=$db_serv_list"$mysql,"
  done
  if [ "$num_host_list" -eq "1" ]; then
    db_serv_list=$db_serv_list"$mysql,"
  fi
  db_serv_list=`echo $db_serv_list | sed -e 's/,$//'`

  num_agent=0
  for agent in $FABAN_INSTANCE; do
    num_agent=$[$num_agent+1]
    agent_serv_list=$agent_serv_list"$agent "
  done
  agent_serv_list=`echo $agent_serv_list | sed -e 's/,$//'`

  cp ./faban-conf/run.xml.OlioDriver ./run.xml.OlioDriver && \
  perl -p -i -e "s/#FABAN_HOST#/$agent_serv_list/" run.xml.OlioDriver && \
  perl -p -i -e "s/#NUM_OF_USER#/$NUM_OF_USER/" run.xml.OlioDriver && \
  perl -p -i -e "s/#NUM_OF_SCALE#/$NUM_OF_SCALE/" run.xml.OlioDriver && \
  perl -p -i -e "s/#NUM_OF_POOL_SIZE#/$NUM_OF_POOL_SIZE/" run.xml.OlioDriver && \
  perl -p -i -e "s/#WRITE_INTERVAL#/$WRITE_INTERVAL/" run.xml.OlioDriver && \
  perl -p -i -e "s/#READ_INTERVAL#/$READ_INTERVAL/" run.xml.OlioDriver && \
  perl -p -i -e "s/#DATABASE_HOST#/$db_host_list/" run.xml.OlioDriver && \
  perl -p -i -e "s/#DATABASE_USER#/$DATABASE_USER/" run.xml.OlioDriver && \
  perl -p -i -e "s/#DATABASE_PASSWORD#/$DATABASE_PASSWORD/" run.xml.OlioDriver && \
  perl -p -i -e "s/#NUM_OF_AGENT#/$num_agent/" run.xml.OlioDriver && \
  ###
  # The following three lines for replacing
  perl -p -i -e "s/#JDBC_DRIVER#/com.mysql.jdbc.ReplicationDriver/" run.xml.OlioDriver && \
  perl -p -i -e "s/#JDBC_CONNECTOR#/jdbc:mysql:replication:/" run.xml.OlioDriver && \
  perl -p -i -e "s/#DATABASE_SERVER#/$db_serv_list/" run.xml.OlioDriver && \
  ###
  # Script snippet for using com.mysql.jdbc.ReplicationDriver driver
  ## perl -p -i -e "s/#JDBC_DRIVER#/com.mysql.jdbc.ReplicationDriver/" run.xml.OlioDriver && \
  ## perl -p -i -e "s/#JDBC_CONNECTOR#/jdbc:mysql:replication:/" run.xml.OlioDriver && \
  ## perl -p -i -e "s/#DATABASE_SERVER#/$db_serv_list/" run.xml.OlioDriver && \
  ###
  # Script snippet for using com.mysql.jdbc.Driver driver
  ## perl -p -i -e "s/#JDBC_DRIVER#/com.mysql.jdbc.Driver/" run.xml.OlioDriver && \
  ## perl -p -i -e "s/#JDBC_CONNECTOR#/jdbc:mysql:/" run.xml.OlioDriver && \
  ## perl -p -i -e "s/#DATABASE_SERVER#/$PROXY_ADDRESS_PORT/" run.xml.OlioDriver && \
  ###
  perl -p -i -e "s/#VARIABLE_LOAD#/$VARIABLE_LOAD/" run.xml.OlioDriver

  ssh root@$1 "mkdir ~/faban/config/profiles/dbadmin"
  scp -r run.xml.OlioDriver root@$1:~/faban/config/profiles/dbadmin/run.xml.OlioDriver && \
  rm run.xml.OlioDriver
  scp -r ./faban-conf/load.txt root@$1:/tmp/load.txt
  # Staring Faban system
  ssh root@$1 "./faban/master/bin/startup.sh"
}

deploy_agent_faban()
{
  # Staring Faban system
  scp -r load.txt.template root@$1:/tmp/load.txt
  ssh root@$1 "./faban/bin/agent"
}

# Deploy Faban system
num_agent=0
for agent in $FABAN_INSTANCE; do
  num_agent=$[$num_agent+1]
  if [ "$num_agent" -eq "1" ]; then
    # Initializing MySQL databases
    master_faban=$agent
    deploy_master_faban $agent &
  else
    deploy_agent_faban $agent &
  fi
done
wait
