/*
 * Copyright 2018 WSO2 Inc. (http://wso2.org)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.wso2.performance.common.jtl.splitter;

import java.math.BigDecimal;

/**
 * Calculated summary statistics.
 */
public class SummaryStats {

    private final long samples;
    private final long errors;
    private final BigDecimal errorPercentage;
    private final BigDecimal throughput;
    private final long min;
    private final long max;
    private final BigDecimal mean;
    private final BigDecimal stddev;
    private final BigDecimal median;
    private final BigDecimal p75;
    private final BigDecimal p90;
    private final BigDecimal p95;
    private final BigDecimal p98;
    private final BigDecimal p99;
    private final BigDecimal p999;
    private final BigDecimal receivedKBytesRate;
    private final BigDecimal sentKBytesRate;

    public SummaryStats(long samples, long errors, BigDecimal errorPercentage, BigDecimal throughput,
                        long min, long max, BigDecimal mean, BigDecimal stddev, BigDecimal median,
                        BigDecimal p75, BigDecimal p90, BigDecimal p95, BigDecimal p98, BigDecimal p99, BigDecimal p999,
                        BigDecimal receivedKBytesRate, BigDecimal sentKBytesRate) {
        this.samples = samples;
        this.errors = errors;
        this.errorPercentage = errorPercentage;
        this.throughput = throughput;
        this.min = min;
        this.max = max;
        this.mean = mean;
        this.stddev = stddev;
        this.median = median;
        this.p75 = p75;
        this.p90 = p90;
        this.p95 = p95;
        this.p98 = p98;
        this.p99 = p99;
        this.p999 = p999;
        this.receivedKBytesRate = receivedKBytesRate;
        this.sentKBytesRate = sentKBytesRate;
    }

    public long getSamples() {
        return samples;
    }

    public long getErrors() {
        return errors;
    }

    public BigDecimal getErrorPercentage() {
        return errorPercentage;
    }

    public BigDecimal getThroughput() {
        return throughput;
    }

    public long getMin() {
        return min;
    }

    public long getMax() {
        return max;
    }

    public BigDecimal getMean() {
        return mean;
    }

    public BigDecimal getStddev() {
        return stddev;
    }

    public BigDecimal getMedian() {
        return median;
    }

    public BigDecimal getP75() {
        return p75;
    }

    public BigDecimal getP90() {
        return p90;
    }

    public BigDecimal getP95() {
        return p95;
    }

    public BigDecimal getP98() {
        return p98;
    }

    public BigDecimal getP99() {
        return p99;
    }

    public BigDecimal getP999() {
        return p999;
    }

    public BigDecimal getReceivedKBytesRate() {
        return receivedKBytesRate;
    }

    public BigDecimal getSentKBytesRate() {
        return sentKBytesRate;
    }
}
