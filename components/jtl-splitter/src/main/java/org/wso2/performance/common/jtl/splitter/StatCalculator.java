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

import org.HdrHistogram.Histogram;
import org.HdrHistogram.Recorder;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Calculate summary statistics from samples.
 */
public class StatCalculator {

    private final Recorder recorder;
    private final Histogram intervalHistogram;
    private final Histogram accumulatedHistogram;

    private long startTimestamp = Long.MAX_VALUE;
    private long endTimestamp;
    private long min = Long.MAX_VALUE;
    private long max = Long.MIN_VALUE;
    private long errors;
    private long totalBytes;
    private long totalSentBytes;

    /**
     * Create StatCalculator with given precision.
     *
     * @param precision Precision to use in HdrHistogram recorder
     */
    public StatCalculator(int precision) {
        this.recorder = new Recorder(precision);
        intervalHistogram = new Histogram(precision);
        accumulatedHistogram = new Histogram(precision);
    }

    public synchronized void addSample(long timestamp, int elapsed, boolean success, int bytes, int sentBytes) {
        recorder.recordValue(elapsed);
        // Update timestamps to calculate throughput
        if (startTimestamp > timestamp) {
            startTimestamp = timestamp;
        }
        long endTimestamp = timestamp + elapsed;
        if (this.endTimestamp < endTimestamp) {
            this.endTimestamp = endTimestamp;
        }
        if (min > elapsed) {
            min = elapsed;
        }
        if (max < elapsed) {
            max = elapsed;
        }
        if (!success) {
            errors++;
        }
        totalBytes += bytes;
        totalSentBytes += sentBytes;
    }

    public synchronized SummaryStats calculate() {
        recorder.getIntervalHistogramInto(intervalHistogram);
        accumulatedHistogram.add(intervalHistogram);
        RoundingMode roundingMode = RoundingMode.HALF_EVEN;
        long samples = accumulatedHistogram.getTotalCount();
        double duration = (endTimestamp - startTimestamp) / 1_000D;
        return new SummaryStats(samples, errors,
                new BigDecimal((samples > 0) ? ((double) errors / samples) * 100D : 0)
                        .setScale(2, roundingMode),
                new BigDecimal(samples / duration).setScale(2, roundingMode),
                min, max,
                new BigDecimal(accumulatedHistogram.getMean()).setScale(2, roundingMode),
                new BigDecimal(accumulatedHistogram.getStdDeviation()).setScale(2, roundingMode),
                new BigDecimal(accumulatedHistogram.getValueAtPercentile(50)).setScale(2, roundingMode),
                new BigDecimal(accumulatedHistogram.getValueAtPercentile(75)).setScale(2, roundingMode),
                new BigDecimal(accumulatedHistogram.getValueAtPercentile(90)).setScale(2, roundingMode),
                new BigDecimal(accumulatedHistogram.getValueAtPercentile(95)).setScale(2, roundingMode),
                new BigDecimal(accumulatedHistogram.getValueAtPercentile(98)).setScale(2, roundingMode),
                new BigDecimal(accumulatedHistogram.getValueAtPercentile(99)).setScale(2, roundingMode),
                new BigDecimal(accumulatedHistogram.getValueAtPercentile(99.9)).setScale(2, roundingMode),
                new BigDecimal((double) totalBytes / 1024 / duration).setScale(2, roundingMode),
                new BigDecimal((double) totalSentBytes / 1024 / duration).setScale(2, roundingMode));
    }
}
