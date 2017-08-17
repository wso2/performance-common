# Common Artifacts for Performance Tests

---
|  Branch | Build Status |
| :------ |:------------ |
| master  | [![Build Status](https://wso2.org/jenkins/buildStatus/icon?job=platform-builds/performance-common)](https://wso2.org/jenkins/job/platform-builds/job/performance-common/) |
---

This repository has common artifacts to be used for Performance Tests.

In [components](components), there are several Java projects and each project builds an executable JAR file.

The [distribution](distribution) directory has the scripts and the Maven project to build the final distribution package
 including all scripts and components to be used for performance tests.

The package (**performance-common-distribution-${version}.tar.gz**) built by the distribution maven module is the
 only package required for performance tests.

## Package contents

Following is the tree view of the contents inside distribution package.

```
|-- java
|   `-- install-java.sh
|-- jmeter
|   |-- install-jmeter.sh
|   |-- jmeter-server-start.sh
|   `-- user.properties
|-- jtl-splitter
|   |-- jtl-splitter-${version}.jar
|   `-- jtl-splitter.sh
|-- netty-service
|   |-- netty-http-echo-service-${version}.jar
|   `-- netty-start.sh
|-- payloads
|   |-- generate-payloads.sh
|   `-- payload-generator-${version}.jar
`-- sar
    `-- install-sar.sh
```

Each directory has an executable script.

This package must be extracted in user home directory in all nodes used for the performance tests.

**Note:** These scripts will work only on Debian based systems like Ubuntu.

See following sections for more details.

### Java Installation

The "java" directory has a simple script named `install-java.sh` to install Oracle Java Development Kit (JDK) on
 64bit Linux.

You must download latest [JDK](http://www.oracle.com/technetwork/java/javase/downloads/index.html).

This script can also install Java Cryptography Extension (JCE) Unlimited Strength Jurisdiction Policy files. You need to
 copy JCE Policy zip file to the same location as the downloaded JDK file (tar.gz)

The script needs to be run as root. The JDK will be extracted to `/usr/lib/jvm` directory.

How to run:

`sudo ./install-java.sh /path/to/jdk-8u*-linux-x64.tar.gz`

### Apache JMeter

Inside "jmeter", directory there are two scripts and JMeter `user.properties` file with recommended configurations for 
 performance tests.

The `install-jmeter.sh` script will extract JMeter and copy the `user.properties` file.

Download latest [Apache JMeter](http://jmeter.apache.org/download_jmeter.cgi).

The Apache JMeter will be extracted to user home directory.

How to run:

`./jmeter/install-jmeter.sh /path/to/apache-jmeter-3.*.tgz`

### JTL Splitter

The "jtl-splitter" directory has a Java program to split a single JTL file into warmup and measurement based on the 
 number of minutes given as the warmup time.

When reporting the results for the performance tests, some specified number of minutes from the beginning of the test 
 are considered as the "Java Warm-up Time" and the from the final results, the warm-up duration is excluded. 
 By doing this, the results reported from the test will only consider the steady-state of the server.

This program should be invoked by the performance testing script after completing the JMeter performance test.

How to run:

`./jtl-splitter.sh results.jtl 5`

Above example splits the `results.jtl` file and the `results-warmup.jtl` file will have the test results for first 5
 minutes. The results after 5 minutes will be in `results-measurement.jtl`.

### Netty Service

The "netty-service" directory has a simple Netty HTTP Echo Service, which will echo back the body data in the HTTP 
 request.

The Netty HTTP Echo Service should be started by the performance testing script.

How to run:

`./netty-start.sh`

The script also accepts an argument to specify the number of milliseconds to sleep before sending response. This is
 useful to test the performance with delays.

### Payloads

The "payloads" directory has a Java program to generate JSON payloads with different sizes.

By default, the script generates 50B, 1KiB, 10KiB, and 100KiB JSON files.

The performance testing script can call this script to generate payloads required for the performance test.

How to run:

`./generate-payloads.sh`

If you want to generate different payload sizes, pass the payload sizes as a single parameter in quotes.

For example:

`./generate-payloads.sh "128 256 512 1024"`

### SAR

The "sar" directory has a simple script to install System Activity Report (SAR) in Linux and configure it to run every
 one minute.

The script needs to be run as root.

How to run:

`sudo ./install-sar.sh`

## License

Copyright 2017 WSO2 Inc. (http://wso2.com)

Licensed under the Apache License, Version 2.0
