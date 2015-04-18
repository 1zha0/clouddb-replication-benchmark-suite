CloudDB Replication Benchmark is a database workload generator based on Cloudstone/Olio(RoR) which aims of evaluating the performance characteristics of database replication in virtualized cloud environment. Using the database and different workloads of the Cloudstone benchmark, the project targets to experimentally assess 
the behavior of the master-slave database replication strategy on Amazon EC2 platforms.

This repository includes both source code for the CloudDB Replication Benchmark workload and scripts for automatic deployment in the cloud.

In order to have the replication delay benchmark work properly, it is suggested to have a [now_microsec()](http://bugs.mysql.com/bug.php?id=8523). A compiled file is included in another directory which contains all possible scripts and archives for automatic deployment in cloud.

The project adopts and modifies [Apache Olio](http://incubator.apache.org/olio/) from [Cloudstone](http://radlab.cs.berkeley.edu/wiki/Projects/Cloudstone) project for database specific benchmark. It also includes tools from [Faban](http://java.net/projects/faban/) under CDDL.

We also kept a copy of source code in [a Github's repository](https://github.com/NICTA/clouddb-replication) for those Github fans.

This project is part of the [CloudDB AutoAdmin](http://cdbslaautoadmin.sourceforge.net/) project.
