#!/bin/bash -e
# Copyright (c) 2018, WSO2 Inc. (http://wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# ----------------------------------------------------------------------------
# Run performance tests on AWS CloudFormation stacks.
# ----------------------------------------------------------------------------

# Source common script
script_dir=$(dirname "$0")
script_dir=$(realpath $script_dir)
. $script_dir/../common/common.sh

# Check commands
check_command bc
check_command aws
check_command unzip
check_command zip
check_command jq
check_command python
check_command ts

script_start_time=$(date +%s)
user_email=""
performance_scripts_distribution=""
default_results_dir="results-$(date +%Y%m%d%H%M%S)"
results_dir="$default_results_dir"
scripts_distribution=""
key_file=""
jmeter_distribution=""
oracle_jdk_distribution=""
stack_name_prefix=""
key_name=""
s3_bucket_name=""
s3_bucket_region=""
jmeter_client_ec2_instance_type=""
jmeter_server_ec2_instance_type=""
netty_ec2_instance_type=""
# GCViewer Jar file to analyze GC logs
gcviewer_jar_path=""
default_minimum_stack_creation_wait_time=5
minimum_stack_creation_wait_time=$default_minimum_stack_creation_wait_time
default_number_of_stacks=1
number_of_stacks=$default_number_of_stacks
default_parallel_parameter_option="u"
parallel_parameter_option="$default_parallel_parameter_option"
ALLOWED_OPTIONS="ubsm"

function usage() {
    echo ""
    echo "Usage: "
    echo "${script_name:-$0} -u <user_email> -f <performance_scripts_distribution> [-d <results_dir>] -k <key_file> -n <key_name>"
    echo "   -j <jmeter_distribution> -o <oracle_jdk_distribution> -g <gcviewer_jar_path>"
    echo "   -s <stack_name_prefix> -b <s3_bucket_name> -r <s3_bucket_region>"
    echo "   -J <jmeter_client_ec2_instance_type> -S <jmeter_server_ec2_instance_type>"
    echo "   -N <netty_ec2_instance_type> "
    if function_exists usageCommand; then
        echo "   $(usageCommand)"
    fi
    echo "   [-t <number_of_stacks>] [-p <parallel_parameter_option>] [-w <minimum_stack_creation_wait_time>]"
    echo "   [-h] -- [run_performance_tests_options]"
    echo ""
    echo "-u: Email of the user running this script."
    echo "-f: Distribution containing the scripts to run performance tests."
    echo "-d: The results directory. Default value is a directory with current time. For example, $default_results_dir."
    echo "-k: Amazon EC2 Key File. Amazon EC2 Key Name must match with this file name."
    echo "-n: Amazon EC2 Key Name."
    echo "-j: Apache JMeter (tgz) distribution."
    echo "-o: Oracle JDK distribution."
    echo "-g: Path of GCViewer Jar file, which will be used to analyze GC logs."
    echo "-s: The Amazon CloudFormation Stack Name Prefix."
    echo "-b: Amazon S3 Bucket Name."
    echo "-r: Amazon S3 Bucket Region."
    echo "-J: Amazon EC2 Instance Type for JMeter Client."
    echo "-S: Amazon EC2 Instance Type for JMeter Server."
    echo "-N: Amazon EC2 Instance Type for Netty (Backend) Service."
    if function_exists usageHelp; then
        echo "$(usageHelp)"
    fi
    echo "-t: Number of stacks to create. Default: $default_number_of_stacks."
    echo "-p: Parameter option of the test script, which will be used to run tests in parallel."
    echo "    Default: $default_parallel_parameter_option. Allowed option characters: $ALLOWED_OPTIONS."
    echo "-w: The minimum time to wait in minutes before polling for cloudformation stack's CREATE_COMPLETE status."
    echo "    Default: $default_minimum_stack_creation_wait_time."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "u:f:d:k:n:j:o:g:s:b:r:J:S:N:t:p:w:h" opts; do
    case $opts in
    u)
        user_email=${OPTARG}
        ;;
    f)
        performance_scripts_distribution=${OPTARG}
        ;;
    d)
        results_dir=${OPTARG}
        ;;
    k)
        key_file=${OPTARG}
        ;;
    n)
        key_name=${OPTARG}
        ;;
    j)
        jmeter_distribution=${OPTARG}
        ;;
    o)
        oracle_jdk_distribution=${OPTARG}
        ;;
    g)
        gcviewer_jar_path=${OPTARG}
        ;;
    s)
        stack_name_prefix=${OPTARG}
        ;;
    b)
        s3_bucket_name=${OPTARG}
        ;;
    r)
        s3_bucket_region=${OPTARG}
        ;;
    J)
        jmeter_client_ec2_instance_type=${OPTARG}
        ;;
    S)
        jmeter_server_ec2_instance_type=${OPTARG}
        ;;
    N)
        netty_ec2_instance_type=${OPTARG}
        ;;
    t)
        number_of_stacks=${OPTARG}
        ;;
    p)
        parallel_parameter_option=${OPTARG}
        ;;
    w)
        minimum_stack_creation_wait_time=${OPTARG}
        ;;
    h)
        usage
        exit 0
        ;;
    \?)
        usage
        exit 1
        ;;
    esac
done
shift "$((OPTIND - 1))"

run_performance_tests_options=("$@")

if [[ -z $user_email ]]; then
    echo "Please provide your email address."
    exit 1
fi

if ! [[ "$user_email" =~ (.+)@(.+) ]]; then
    echo "Provided email address \"$user_email\" is invalid."
    exit 1
fi

if [[ ! -f $performance_scripts_distribution ]]; then
    echo "Please provide Performance Distribution."
    exit 1
fi

performance_scripts_distribution_filename=$(basename $performance_scripts_distribution)

if [[ ${performance_scripts_distribution_filename: -7} != ".tar.gz" ]]; then
    echo "Performance Distribution must have .tar.gz extension"
    exit 1
fi

if [[ -z $results_dir ]]; then
    echo "Please provide a name to the results directory."
    exit 1
fi

if [[ -d $results_dir ]]; then
    echo "Results directory already exists. Please give a new name to the results directory."
    exit 1
fi

if [[ ! -f $key_file ]]; then
    echo "Please provide the key file."
    exit 1
fi

if [[ ${key_file: -4} != ".pem" ]]; then
    echo "AWS EC2 Key file must have .pem extension"
    exit 1
fi

if [[ -z $key_name ]]; then
    echo "Please provide the key name."
    exit 1
fi

key_filename=$(basename "$key_file")

if [[ "${key_filename%.*}" != "$key_name" ]]; then
    echo "WARNING: Key file does not match with the key name."
fi

if [[ ! -f $jmeter_distribution ]]; then
    echo "Please specify the JMeter distribution file (apache-jmeter-*.tgz)"
    exit 1
fi

jmeter_distribution_filename=$(basename $jmeter_distribution)

if [[ ${jmeter_distribution_filename: -4} != ".tgz" ]]; then
    echo "Please provide the JMeter tgz distribution file (apache-jmeter-*.tgz)"
    exit 1
fi

if [[ ! -f $oracle_jdk_distribution ]]; then
    echo "Please specify the Oracle JDK distribution file (jdk-8u*-linux-x64.tar.gz)"
    exit 1
fi

oracle_jdk_distribution_filename=$(basename $oracle_jdk_distribution)

if ! [[ $oracle_jdk_distribution_filename =~ ^jdk-8u[0-9]+-linux-x64.tar.gz$ ]]; then
    echo "Please specify a valid Oracle JDK distribution file (jdk-8u*-linux-x64.tar.gz)"
    exit 1
fi

if [[ ! -f $gcviewer_jar_path ]]; then
    echo "Please specify the path to GCViewer JAR file."
    exit 1
fi

if [[ -z $stack_name_prefix ]]; then
    echo "Please provide the stack name prefix."
    exit 1
fi

if [[ -z $s3_bucket_name ]]; then
    echo "Please provide S3 bucket name."
    exit 1
fi

if [[ -z $s3_bucket_region ]]; then
    echo "Please provide S3 bucket region."
    exit 1
fi

if [[ -z $jmeter_client_ec2_instance_type ]]; then
    echo "Please provide the Amazon EC2 Instance Type for JMeter Client."
    exit 1
fi

if [[ -z $jmeter_server_ec2_instance_type ]]; then
    echo "Please provide the Amazon EC2 Instance Type for JMeter Server."
    exit 1
fi

if [[ -z $netty_ec2_instance_type ]]; then
    echo "Please provide the Amazon EC2 Instance Type for Netty (Backend) Service."
    exit 1
fi

if ! [[ $minimum_stack_creation_wait_time =~ ^[0-9]+$ ]]; then
    echo "Please provide a valid minimum time to wait before polling for cloudformation stack's CREATE_COMPLETE status."
    exit 1
fi

if ! [[ $number_of_stacks =~ ^[0-9]+$ ]]; then
    echo "Please provide a valid number of stacks."
    exit 1
fi

if [[ -z $parallel_parameter_option ]]; then
    echo "Please provide the option character to parallelize tests."
    exit 1
fi

if ! [[ ${#parallel_parameter_option} -eq 1 ]]; then
    echo "Please provide a single option character to parallelize tests."
    exit 1
fi

if ! [[ $ALLOWED_OPTIONS == *"$parallel_parameter_option"* ]]; then
    echo "Invalid option. Allowed options to parallelize tests are $ALLOWED_OPTIONS."
    exit 1
fi

if function_exists validate; then
    validate
fi

# Allow to change the script name
run_performance_tests_script_name=${run_performance_tests_script_name:-run-performance-tests.sh}

declare -a required_variables=("aws_cloudformation_template_filename" "application_name" "ec2_instance_name"
    "metrics_file_prefix" "run_performance_tests_script_name")

for var in "${required_variables[@]}"; do
    if [[ -z ${!var} ]]; then
        echo "Required variable: ${var} is not defined!"
        exit 1
    fi
done

if ! function_exists get_columns; then
    echo "Please define a function named 'get_columns' in the script to get the columns to be included in markdown file."
    exit 1
fi

echo "Checking whether python requirements are installed..."
pip install -r $script_dir/python-requirements.txt

# Use absolute path
results_dir=$(realpath $results_dir)
mkdir $results_dir
echo "Results will be downloaded to $results_dir"
# Get absolute path of GCViewer
gcviewer_jar_path=$(realpath $gcviewer_jar_path)
# Copy scripts to results directory (in case if we need to use the scripts again)
mkdir $results_dir/scripts
cp -v $performance_scripts_distribution $results_dir/scripts/

aws_region="$(aws configure get region)"
echo "Current AWS Region: $aws_region"

# Save metadata
declare -A test_parameters
test_parameters[application_name]="$application_name"
test_parameters[number_of_stacks]="$number_of_stacks"
test_parameters[jmeter_client_ec2_instance_type]="$jmeter_client_ec2_instance_type"
test_parameters[jmeter_server_ec2_instance_type]="$jmeter_server_ec2_instance_type"
test_parameters[netty_ec2_instance_type]="$netty_ec2_instance_type"

if function_exists get_test_metadata; then
    while IFS='=' read -r key value; do
        test_parameters[$key]="$value"
    done < <(get_test_metadata)
fi

test_parameters_json="."
declare -a test_parameters_args
for key in "${!test_parameters[@]}"; do
    test_parameters_json+=" | .[\"$key\"]=\$$key"
    test_parameters_args+=("--arg" "$key" "${test_parameters[$key]}")
done
jq -n "${test_parameters_args[@]}" "$test_parameters_json" >$results_dir/cf-test-metadata.json

estimate_command="$script_dir/../jmeter/${run_performance_tests_script_name} -t ${run_performance_tests_options[@]}"
echo "Estimating total time for performance tests: $estimate_command"
# Estimating this script will also validate the options. It's important to validate options before creating the stack.
$estimate_command

# Save test metadata
mv test-metadata.json $results_dir
mv test-duration.json $results_dir

# Region Display Names
# The AWS Pricing API uses display names to filter location.
# There is no API to get AWS Region Display Name.
# See also: https://maori.geek.nz/aws-api-to-get-ec2-instance-prices-b04a155860da
declare -A region_names
region_names[us_east_1]="US East (N. Virginia)"
region_names[us_east_2]="US East (Ohio)"
region_names[us_west_1]="US West (N. California)"
region_names[us_west_2]="US West (Oregon)"
region_names[ap_east_1]="Asia Pacific (Hong Kong)"
region_names[ap_south_1]="Asia Pacific (Mumbai)"
region_names[ap_northeast_2]="Asia Pacific (Seoul)"
region_names[ap_southeast_1]="Asia Pacific"
region_names[ap_southeast_2]="Asia Pacific (Sydney)"
region_names[ap_northeast_1]="Asia Pacific (Tokyo)"
region_names[ca_central_1]="Canada (Central)"
region_names[eu_central_1]="EU (Frankfurt)"
region_names[eu_west_1]="EU (Ireland)"
region_names[eu_west_2]="EU (London)"
region_names[eu_west_3]="EU (Paris)"
region_names[eu_north_1]="EU (Stockholm)"
region_names[sa_east_1]="South America (Sao Paulo)"

# Estimate AWS EC2 cost
echo "Getting the AWS EC2 Pricing for given instance types..."
total_cost="0"
while read count ec2_instance_type; do
    pricing_json="$results_dir/pricing.json"
    price_in_usd=""
    total_hours=""
    region_name="${aws_region//-/_}"
    if aws pricing get-products --filters \
        Type=TERM_MATCH,Field=ServiceCode,Value=AmazonEC2 \
        Type=TERM_MATCH,Field=InstanceType,Value=$ec2_instance_type \
        Type=TERM_MATCH,Field=operatingSystem,Value=Linux \
        Type=TERM_MATCH,Field=tenancy,Value=Shared \
        Type=TERM_MATCH,Field=capacitystatus,Value=Used \
        Type=TERM_MATCH,Field=preInstalledSw,Value=NA \
        "Type=TERM_MATCH,Field=location,Value=${region_names[$region_name]}" \
        --format-version aws_v1 --max-results 1 \
        --service-code AmazonEC2 --output json >$pricing_json; then
        price_in_usd="$(jq -r '.PriceList[] | fromjson.terms.OnDemand[].priceDimensions[].pricePerUnit.USD' $pricing_json || echo "")"
        total_duration="$(jq -r '.total_duration' $results_dir/test-duration.json || echo "")"
        total_hours="$(bc <<<"scale=4;hrs=$total_duration/60;scale=0;if (hrs % 60) hrs/60+1 else hrs/60" || echo "")"
    fi
    if [[ -n $price_in_usd ]] && [[ -n $total_hours ]]; then
        cost="$(bc <<<"scale=4;$count*$price_in_usd*$total_hours" | awk '{printf "%.4f\n", $0}')"
        total_cost="$(bc <<<"$total_cost+$cost" | awk '{printf "%.4f\n", $0}' || echo "0")"
        printf "Cost to run %s instance(s) from instance type %10s is USD %s.\n" "$count" "$ec2_instance_type" "$cost"
    else
        printf "WARNING: Could not calculate the cost to run %10s instance(s) from instance type %s.\n" "$count" "$ec2_instance_type"
    fi
done < <(jq -r '. as $type | keys_unsorted[] | select(endswith("ec2_instance_type")) | $type[.]' $results_dir/cf-test-metadata.json | sort | uniq -c | sort -nr)
if [[ $(bc <<<"scale=4;$total_cost > 0") -eq 1 ]]; then
    printf "\nTotal cost is USD %s.\n\n" "$total_cost"
fi

declare -a performance_test_options

if [[ $number_of_stacks -gt 1 ]]; then
    # Read options given to the performance test script. Refer jmeter/perf-test-common.sh
    declare -a options
    # Flag to check whether next parameter is an argument to $parallel_parameter_option
    next_opt_param=false
    for opt in ${run_performance_tests_options[@]}; do
        if [[ $opt == -$parallel_parameter_option* ]]; then
            optarg="${opt:2}"
            if [[ ! -z $optarg ]]; then
                options+=("${optarg}")
            else
                next_opt_param=true
            fi
        else
            if [[ $next_opt_param == true ]]; then
                options+=("${opt}")
                next_opt_param=false
            else
                run_performance_tests_remaining_options+=("${opt}")
            fi
        fi
    done
    minimum_params_per_stack=$(bc <<<"scale=0; ${#options[@]}/${number_of_stacks}")
    remaining_params=$(bc <<<"scale=0; ${#options[@]}%${number_of_stacks}")
    echo "Parallel option parameters: ${#options[@]}"
    echo "Number of stacks: ${number_of_stacks}"
    echo "Minimum parameters per stack: $minimum_params_per_stack"
    echo "Remaining parameters after distributing evenly: $remaining_params"

    option_counter=0
    remaining_option_counter=0
    for ((i = 0; i < $number_of_stacks; i++)); do
        declare -a options_per_stack=()
        for ((j = 0; j < $minimum_params_per_stack; j++)); do
            options_per_stack+=("${options[$option_counter]}")
            let option_counter=option_counter+1
        done
        if [[ $remaining_option_counter -lt $remaining_params ]]; then
            options_per_stack+=("${options[$option_counter]}")
            let option_counter=option_counter+1
            let remaining_option_counter=remaining_option_counter+1
        fi
        options_list=""
        for parameter_value in ${options_per_stack[@]}; do
            options_list+="-${parallel_parameter_option} ${parameter_value} "
        done
        performance_test_options+=("${options_list} ${run_performance_tests_remaining_options[*]}")
    done
else
    performance_test_options+=("${run_performance_tests_options[*]}")
fi

declare -a jmeter_servers_per_stack

echo "Number of stacks to create: $number_of_stacks."
max_jmeter_servers=1
# echo "Performance test options given to stack(s): "
for ((i = 0; i < ${#performance_test_options[@]}; i++)); do
    declare -a options_array=(${performance_test_options[$i]})
    declare -a concurrent_users=()
    # Flag to check whether next parameter is an argument to -u
    next_opt_param=false
    for opt in ${options_array[@]}; do
        if [[ $opt == -$parallel_parameter_option* ]]; then
            optarg="${opt:2}"
            if [[ ! -z $optarg ]]; then
                concurrent_users+=("${optarg}")
            else
                next_opt_param=true
            fi
        else
            if [[ $next_opt_param == true ]]; then
                concurrent_users+=("${opt}")
                next_opt_param=false
            fi
        fi
    done

    # Determine JMeter Servers
    max_concurrent_users="0"
    for users in ${concurrent_users[@]}; do
        if [[ $users -gt $max_concurrent_users ]]; then
            max_concurrent_users=$users
        fi
    done
    jmeter_servers=1
    if [[ $max_concurrent_users -gt 500 ]]; then
        jmeter_servers=2
        max_jmeter_servers=2
    fi
    jmeter_servers_per_stack+=("$jmeter_servers")
    performance_test_options[$i]+=" -n $jmeter_servers"
    estimate_command="$script_dir/../jmeter/${run_performance_tests_script_name} -t ${performance_test_options[$i]}"
    echo "$(($i + 1)): Estimating total time for the tests in stack $(($i + 1)) with $jmeter_servers JMeter server(s) handling a maximum of $max_concurrent_users concurrent users: $estimate_command"
    $estimate_command
done
echo "Maximum number of JMeter(s): $max_jmeter_servers"

temp_dir=$(mktemp -d)

# Get absolute paths
key_file=$(realpath $key_file)
performance_scripts_distribution=$(realpath $performance_scripts_distribution)
jmeter_distribution=$(realpath $jmeter_distribution)
oracle_jdk_distribution=$(realpath $oracle_jdk_distribution)

ln -s $key_file $temp_dir/$key_filename
ln -s $performance_scripts_distribution $temp_dir/$performance_scripts_distribution_filename
ln -s $jmeter_distribution $temp_dir/$jmeter_distribution_filename
ln -s $oracle_jdk_distribution $temp_dir/$oracle_jdk_distribution_filename

if function_exists create_links; then
    create_links
fi

echo "Syncing files in $temp_dir to S3 Bucket $s3_bucket_name..."
aws s3 sync --quiet --delete $temp_dir s3://$s3_bucket_name

echo "Listing files in S3 Bucket $s3_bucket_name..."
aws --region $s3_bucket_region s3 ls --summarize s3://$s3_bucket_name

declare -A cf_parameters
cf_parameters[UserEmail]="$user_email"
cf_parameters[KeyName]="$key_name"
cf_parameters[BucketName]="$s3_bucket_name"
cf_parameters[BucketRegion]="$s3_bucket_region"
cf_parameters[PerformanceDistributionName]="$performance_scripts_distribution_filename"
cf_parameters[JMeterDistributionName]="$jmeter_distribution_filename"
cf_parameters[OracleJDKDistributionName]="$oracle_jdk_distribution_filename"
cf_parameters[JMeterClientInstanceType]="$jmeter_client_ec2_instance_type"
cf_parameters[JMeterServerInstanceType]="$jmeter_server_ec2_instance_type"
cf_parameters[BackendInstanceType]="$netty_ec2_instance_type"

if function_exists get_cf_parameters; then
    while IFS='=' read -r key value; do
        cf_parameters[$key]="$value"
    done < <(get_cf_parameters)
fi

function delete_stack() {
    local stack_id="$1"
    local stack_delete_start_time=$(date +%s)
    echo "Deleting the stack: $stack_id"
    aws cloudformation delete-stack --stack-name $stack_id

    echo "Polling till the stack deletion completes..."
    aws cloudformation wait stack-delete-complete --stack-name $stack_id
    printf "Stack ($stack_id) deletion time: %s\n" "$(format_time $(measure_time $stack_delete_start_time))"
}

declare -a stack_ids

function exit_handler() {
    #Delete stack if it's already running
    for stack_id in ${stack_ids[@]}; do
        if aws cloudformation describe-stacks --stack-name $stack_id >/dev/null 2>&1; then
            delete_stack $stack_id
        fi
    done
    printf "Script execution time: %s\n" "$(format_time $(measure_time $script_start_time))"
}

trap exit_handler EXIT

# Find latest Ubuntu AMI ID
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html
latest_ami_id="$(aws ec2 describe-images --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-????????' 'Name=state,Values=available' --output json | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId')"
echo "Latest Ubuntu AMI ID: $latest_ami_id"

# Create stacks
stack_create_start_time=$(date +%s)
for ((i = 0; i < ${#performance_test_options[@]}; i++)); do
    stack_name="${stack_name_prefix}$(($i + 1))"
    stack_results_dir="$results_dir/results-$(($i + 1))"
    mkdir -p $stack_results_dir
    cf_template=$stack_results_dir/${aws_cloudformation_template_filename}
    jmeter_servers=${jmeter_servers_per_stack[$i]}
    echo "JMeter Servers: $jmeter_servers"
    $script_dir/create-template.py ${CREATE_TEMPLATE_OPTS} --template-name ${aws_cloudformation_template_filename} \
        --region $aws_region \
        --ami-id $latest_ami_id \
        --output-name $cf_template \
        --jmeter-servers $jmeter_servers --start-bastion
    echo "Validating stack: $stack_name: $cf_template"
    aws cloudformation validate-template --template-body file://$cf_template
    if [[ $jmeter_servers -eq 1 ]]; then
        cf_parameters[JMeterClientInstanceType]="$jmeter_server_ec2_instance_type"
    fi

    cf_parameters_str=""
    for key in "${!cf_parameters[@]}"; do
        cf_parameters_str+=" ParameterKey=${key},ParameterValue=${cf_parameters[$key]}"
    done
    create_stack_command="aws cloudformation create-stack --stack-name $stack_name \
        --template-body file://$cf_template --parameters $cf_parameters_str \
        --capabilities CAPABILITY_IAM"

    echo "Creating stack $stack_name..."
    echo "$create_stack_command"
    # Create stack
    stack_id="$($create_stack_command)"
    # stack_id="Stack"
    stack_ids+=("$stack_id")
    echo "Created stack: $stack_name. ID: $stack_id"
done

function download_files() {
    local stack_id="$1"
    local stack_name="$2"
    local stack_results_dir="$3"
    local suffix="$(date +%Y%m%d%H%M%S)"
    local stack_files_dir="$stack_results_dir/stack-files"
    mkdir -p $stack_files_dir
    local stack_resources_json=$stack_files_dir/stack-resources-$suffix.json
    echo "Saving $stack_name stack resources to $stack_resources_json"
    aws cloudformation describe-stack-resources --stack-name $stack_id --no-paginate --output json >$stack_resources_json
    local vpc_id="$(jq -r '.StackResources[] | select(.LogicalResourceId=="VPC") | .PhysicalResourceId' $stack_resources_json)"
    if [[ ! -z $vpc_id ]]; then
        echo "VPC ID: $vpc_id"
        local stack_instances_json=$stack_files_dir/stack-instances-$suffix.json
        aws ec2 describe-instances --filters "Name=vpc-id, Values="$vpc_id"" --query "Reservations[*].Instances[*]" --no-paginate --output json >$stack_instances_json
        # Try to get a public IP
        local instance_public_ip="$(jq -r 'first(.[][] | .PublicIpAddress // empty)' $stack_instances_json)"
        if [[ ! -z $instance_public_ip ]]; then
            local instance_ips_file=$stack_files_dir/stack-instance-ips-$suffix.txt
            cat $stack_instances_json | jq -r '.[][] | (.Tags[] | select(.Key=="Name")) as $tags | ($tags["Value"] + "/" + .PrivateIpAddress) | tostring' >$instance_ips_file
            echo "Private IPs in $instance_ips_file: "
            cat $instance_ips_file
            echo "Uploading $instance_ips_file to $instance_public_ip"
            if scp -i $key_file -o "StrictHostKeyChecking=no" $instance_ips_file ubuntu@$instance_public_ip:; then
                download_files_command="ssh -i $key_file -o "StrictHostKeyChecking=no" ubuntu@$instance_public_ip ./cloudformation/download-files.sh -f $(basename $instance_ips_file) -k private_key.pem -o /home/ubuntu"
                echo "Download files command: $download_files_command"
                $download_files_command
                echo "Downloading files.zip"
                local files_zip_file=$stack_files_dir/files-$suffix.zip
                scp -i $key_file -o "StrictHostKeyChecking=no" ubuntu@$instance_public_ip:files.zip $files_zip_file
                local files_dir="$stack_results_dir/files"
                mkdir -p $files_dir
                echo "Extracting files.zip to $files_dir"
                unzip -o $files_zip_file -d $files_dir
            fi
        fi
    else
        echo "WARNING: VPC ID not found!"
    fi
}

function save_logs_and_delete_stack() {
    local stack_id="$1"
    local stack_name="$2"
    local stack_results_dir="$3"
    # Get stack events
    local stack_events_json=$stack_results_dir/stack-events.json
    echo "Saving $stack_name stack events to $stack_events_json"
    aws cloudformation describe-stack-events --stack-name $stack_id --no-paginate --output json >$stack_events_json
    # Check whether there are any failed events
    cat $stack_events_json | jq '.StackEvents | .[] | select ( .ResourceStatus == "CREATE_FAILED" )'

    # Download log events
    local log_group_name="${stack_name}-CloudFormationLogs"
    local log_streams_json=$stack_results_dir/log-streams.json
    if aws logs describe-log-streams --log-group-name $log_group_name --output json >$log_streams_json; then
        local log_events_file=$stack_results_dir/log-events.log
        for log_stream in $(cat $log_streams_json | jq -r '.logStreams | .[] | .logStreamName'); do
            echo "[$log_group_name] Downloading log events from stream: $log_stream..."
            echo "#### The beginning of log events from $log_stream" >>$log_events_file
            aws logs get-log-events --log-group-name $log_group_name --log-stream-name $log_stream --output text >>$log_events_file
            echo -ne "\n\n#### The end of log events from $log_stream\n\n" >>$log_events_file
        done
    else
        echo "WARNING: There was an error getting log streams from the log group $log_group_name. Check whether AWS CloudWatch logs are enabled."
    fi

    # Download files
    download_files ${stack_id} ${stack_name} ${stack_results_dir}

    if [ "$SUSPEND" = true ]; then
        echo "SUSPEND is true, holding the deletion of stack: $stack_id"
        if ! sleep infinity; then
            echo "Sleep terminated! Proceeding to delete the stack: $stack_id"
        fi
    fi

    delete_stack $stack_id
}

function wait_and_download_files() {
    local stack_id="$1"
    local stack_name="$2"
    local stack_results_dir="$3"
    local wait_time="$4"
    sleep $wait_time
    local suffix="$(date +%Y%m%d%H%M%S)"
    local stack_files_dir="$stack_results_dir/stack-files"
    mkdir -p $stack_files_dir
    local stack_status_json=$stack_files_dir/stack-status-$suffix.json
    echo "Saving $stack_name stack status to $stack_status_json"
    aws cloudformation describe-stacks --stack-name $stack_id --no-paginate --output json >$stack_status_json
    local stack_status="$(jq -r '.Stacks[] | .StackStatus' $stack_status_json || echo "")"
    echo "Current status of $stack_name stack is $stack_status"
    if [[ "$stack_status" != "CREATE_COMPLETE" ]]; then
        download_files ${stack_id} ${stack_name} ${stack_results_dir}
    fi
}

function run_perf_tests_in_stack() {
    local index=$1
    local stack_id=$2
    local stack_name=$3
    local stack_results_dir=$4
    trap "save_logs_and_delete_stack ${stack_id} ${stack_name} ${stack_results_dir}" EXIT
    trap "save_logs_and_delete_stack ${stack_id} ${stack_name} ${stack_results_dir}" RETURN
    printf "Running performance tests on '%s' stack.\n" "$stack_name"

    # Download files periodically
    for wait_time in $(seq 5 5 30); do
        wait_and_download_files ${stack_id} ${stack_name} ${stack_results_dir} ${wait_time}m &
    done
    # Sleep for sometime before waiting
    # This is required since the 'aws cloudformation wait stack-create-complete' will exit with a
    # return code of 255 after 120 failed checks. The command polls every 30 seconds, which means that the
    # maximum wait time is one hour.
    # Due to the dependencies in CloudFormation template, the stack creation may take more than one hour.
    echo "Waiting ${minimum_stack_creation_wait_time}m before polling for CREATE_COMPLETE status of the stack: $stack_name"
    sleep ${minimum_stack_creation_wait_time}m
    # Wait till completion
    echo "Polling till the stack creation completes..."
    aws cloudformation wait stack-create-complete --stack-name $stack_id
    printf "Stack creation time: %s\n" "$(format_time $(measure_time $stack_create_start_time))"

    # Get stack resources
    local stack_resources_json=$stack_results_dir/stack-resources.json
    echo "Saving $stack_name stack resources to $stack_resources_json"
    aws cloudformation describe-stack-resources --stack-name $stack_id --no-paginate --output json >$stack_resources_json
    # Print EC2 instances
    echo "AWS EC2 instances: "
    cat $stack_resources_json | jq -r '.StackResources | .[] | select ( .ResourceType == "AWS::EC2::Instance" ) | .LogicalResourceId'

    echo "Getting JMeter Client Public IP..."
    jmeter_client_ip="$(aws cloudformation describe-stacks --stack-name $stack_id --query 'Stacks[0].Outputs[?OutputKey==`JMeterClientPublicIP`].OutputValue' --output text)"
    echo "JMeter Client Public IP: $jmeter_client_ip"

    ssh_command_prefix="ssh -i $key_file -o "StrictHostKeyChecking=no" -T ubuntu@$jmeter_client_ip"
    # Run performance tests
    run_remote_tests_command="$ssh_command_prefix ./jmeter/${run_performance_tests_script_name} ${performance_test_options[$index]}"
    echo "Running performance tests: $run_remote_tests_command"
    # Handle any error and let the script continue.
    $run_remote_tests_command || echo "Remote test ssh command failed: $run_remote_tests_command"

    echo "Downloading results-without-jtls.zip"
    # Download results-without-jtls.zip
    scp -i $key_file -o "StrictHostKeyChecking=no" ubuntu@$jmeter_client_ip:results-without-jtls.zip $stack_results_dir
    echo "Downloading results.zip"
    # Download results.zip
    scp -i $key_file -o "StrictHostKeyChecking=no" ubuntu@$jmeter_client_ip:results.zip $stack_results_dir

    if [[ ! -f $stack_results_dir/results-without-jtls.zip ]]; then
        echo "Failed to download the results-without-jtls.zip"
        exit 500
    fi

    if [[ ! -f $stack_results_dir/results.zip ]]; then
        echo "Failed to download the results.zip"
        exit 500
    fi
}

for ((i = 0; i < ${#stack_ids[@]}; i++)); do
    stack_id=${stack_ids[$i]}
    stack_name="${stack_name_prefix}$(($i + 1))"
    stack_results_dir="$results_dir/results-$(($i + 1))"
    log_file="${stack_results_dir}/run.log"
    run_perf_tests_in_stack $i ${stack_id} ${stack_name} ${stack_results_dir} 2>&1 | ts "[${stack_name}] [%Y-%m-%d %H:%M:%S]" | tee ${log_file} &
done

# See current jobs
echo "Jobs: "
jobs
echo "Waiting till all performance test jobs are completed..."
# Wait till parallel tests complete
wait

declare -a system_information_files

# Extract all results.
for ((i = 0; i < ${#performance_test_options[@]}; i++)); do
    stack_results_dir="$results_dir/results-$(($i + 1))"
    unzip -nq ${stack_results_dir}/results-without-jtls.zip -x '*/test-metadata.json' -d $results_dir
    system_info_file="${stack_results_dir}/files/${ec2_instance_name}/system-info.json"
    if [[ -f $system_info_file ]]; then
        system_information_files+=("$system_info_file")
    fi
done
cd $results_dir
echo "Combining system information in following files: ${system_information_files[@]}"
# Join json files containing system information and create an array
jq -s . "${system_information_files[@]}" >all-system-info.json
# Copy metadata before creating CSV
cp cf-test-metadata.json test-metadata.json results
echo "Creating summary.csv..."
# Create warmup summary CSV
$script_dir/../jmeter/create-summary-csv.sh ${create_csv_opts} -d results -n "${application_name}" -p "${metrics_file_prefix}" -j $max_jmeter_servers -g "${gcviewer_jar_path}" -i -w -o summary-warmup.csv
# Create measurement summary CSV
$script_dir/../jmeter/create-summary-csv.sh ${create_csv_opts} -d results -n "${application_name}" -p "${metrics_file_prefix}" -j $max_jmeter_servers -g "${gcviewer_jar_path}" -i -o summary.csv
# Zip results
zip -9qmr results-all.zip results/

# Use following to get all column names:
echo "Available column names:"
while read -r line; do echo "\"$line\""; done < <($script_dir/../jmeter/create-summary-csv.sh ${create_csv_opts} -n "${application_name}" -j $max_jmeter_servers -i -x)
echo -ne "\n\n"

declare -a column_names

while read column_name; do
    column_names+=("$column_name")
done < <(get_columns)

echo "Creating summary results markdown file... Using column names: ${column_names[@]}"
$script_dir/../jmeter/create-summary-markdown.py --json-parameters parameters=cf-test-metadata.json,parameters=test-metadata.json,instances=all-system-info.json \
    --column-names "${column_names[@]}"

function print_summary() {
    cat $1 | cut -d, -f 1-13 | column -t -s,
}

echo -ne "\n\n"
echo "Warmup Results:"
print_summary summary-warmup.csv

echo -ne "\n\n"
echo "Measurement Results:"
print_summary summary.csv

awk -F, '{ if ($8 > 0)  print }' summary.csv >summary-errors.csv

if [[ $(wc -l <summary-errors.csv) -gt 1 ]]; then
    echo -ne "\n\n"
    echo "WARNING: There are errors in measurement results! Please check."
    print_summary summary-errors.csv
fi
