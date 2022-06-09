# {{ parameters.application_name }} Performance Test Results

These are the performance test results of a [Netty](https://netty.io/) based Back-end service which echoes back any request
posted to it after a specified period of time. This is the Back-end that is used in the performance tests of WSO2 products.

| Test Scenarios | Description |
| --- | --- |
{%- for test_scenario in parameters.test_scenarios %}
| {{test_scenario.display_name}} | {{test_scenario.description}} |
{%- endfor %}

Our test client is [Apache JMeter](https://jmeter.apache.org/index.html). We test each scenario for a fixed duration of
time. We split the test results into warmup and measurement parts and use the measurement part to compute the
performance metrics.

We run the Back-end performance tests under different numbers of concurrent users, GraphQL queries and Back-end service
delays.

The main performance metrics:

1. **Throughput**: The number of requests that the {{ parameters.application_name }} processes during a specific time interval (e.g. per second).
2. **Response Time**: The end-to-end latency for an operation of invoking an API. The complete distribution of response times was recorded.

In addition to the above metrics, we measure the load average and several memory-related metrics.

The following are the test parameters.

| Test Parameter | Description | Values |
| --- | --- | --- |
| Scenario Name | The name of the test scenario. | Refer to the above table. |
| Heap Size | The amount of memory allocated to the application | {{ parameters.heap_sizes|join(', ') }} |
| Concurrent Users | The number of users accessing the application at the same time. | {{ parameters.concurrent_users|join(', ') }} |
| GraphQL Query | The GraphQL query number | {{ parameters.query_numbers|join(', ') }} |
| Back-end Delay (ms) | The delay added by the Back-end service. | {{ parameters.backend_sleep_times|join(', ') }} |

The duration of each test is **{{ parameters.test_duration }} seconds**. The warm-up period is **{{ parameters.warmup_time }} seconds**.
The measurement results are collected after the warm-up period.

The performance tests were executed on {{ parameters.number_of_stacks }} AWS CloudFormation stack{{ parameters.number_of_stacks|pluralize }}.
{% for instance in instances %}
System information for {{ parameters.application_name }} in {{ loop.index|humanize_ordinal }} AWS CloudFormation stack.

| Class | Subclass | Description | Value |
| --- | --- | --- | --- |
{%- for system_info in instance.system_info %}
| {{ system_info['class'] }} | {{ system_info['subclass'] }} | {{ system_info['description'] }} | {{ system_info['value'] }} |
{%- endfor %}
{%- endfor %}

The following are the measurements collected from each performance test conducted for a given combination of
test parameters.

| Measurement | Description |
| --- | --- |
| Error % | Percentage of requests with errors |
| Average Response Time (ms) | The average response time of a set of results |
| Standard Deviation of Response Time (ms) | The “Standard Deviation” of the response time. |
| 99th Percentile of Response Time (ms) | 99% of the requests took no more than this time. The remaining samples took at least as long as this |
| Throughput (Requests/sec) | The throughput measured in requests per second. |
| Average Memory Footprint After Full GC (M) | The average memory consumed by the application after a full garbage collection event. |

The following is the summary of performance test results collected for the measurement period.

| {% for column_name in column_names %} {{ column_name }} |{%- endfor %}
| {%- for column_name in column_names %}---{% if not loop.first %}:{% endif%}|{%- endfor %}
{%- for row in rows %}
| {% for column_name in column_names %} {{ row[column_name] }} |{% endfor %}
{%- endfor %}
