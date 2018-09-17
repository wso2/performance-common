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

import org.apache.jmeter.samplers.SampleResult;
import org.apache.jmeter.util.JMeterUtils;
import org.apache.jmeter.visualizers.SamplingStatCalculator;
import org.testng.Assert;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.DataProvider;
import org.testng.annotations.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Random;

/**
 * Test summary statistics.
 */
public class StatCalculatorTest {

    private StatCalculator statCalculator;
    // JMeter Calculator
    private SamplingStatCalculator samplingStatCalculator;

    private static final int NO_OF_SAMPLES = 99_999;

    private Random random;

    @BeforeClass
    private void init() {
        JMeterUtils.loadJMeterProperties(Objects.requireNonNull(Thread.currentThread().getContextClassLoader()
                .getResource("user.properties")).getPath());
        statCalculator = new StatCalculator(2);
        samplingStatCalculator = new SamplingStatCalculator();
        random = new Random();
    }

    @DataProvider(name = "samples")
    public Object[][] samples() {
        long startTimestamp = System.currentTimeMillis();
        List<Object[]> samples = new ArrayList<>();
        for (int i = 0; i < NO_OF_SAMPLES; i++) {
            samples.add(new Object[]{startTimestamp + random.nextInt(1_000), random.nextInt(1_000),
                    random.nextBoolean(),
                    random.nextInt(10_000), random.nextInt(10_000)});
        }
        return samples.toArray(new Object[samples.size()][4]);
    }

    @Test(dataProvider = "samples")
    public void testSamples(long timestamp, int elapsed, boolean success, int bytes, int sentBytes) {
        statCalculator.addSample(timestamp, elapsed, success, bytes, sentBytes);
        SampleResult sampleResult = new SampleResult();
        sampleResult.setStampAndTime(timestamp, elapsed);
        sampleResult.setSuccessful(success);
        sampleResult.setBytes((long) bytes);
        sampleResult.setSentBytes((long) sentBytes);
        samplingStatCalculator.addSample(sampleResult);
        final SummaryStats summaryStats = statCalculator.calculate();
        Assert.assertEquals(summaryStats.getSamples(), samplingStatCalculator.getCount());
        Assert.assertEquals(summaryStats.getErrors(), samplingStatCalculator.getErrorCount());

    }

    @Test(dependsOnMethods = "testSamples")
    public void testStatistics() {
        final SummaryStats summaryStats = statCalculator.calculate();
        Assert.assertEquals(summaryStats.getSamples(), NO_OF_SAMPLES);
        Assert.assertEquals(summaryStats.getSamples(), samplingStatCalculator.getCount());
        Assert.assertEquals(summaryStats.getErrors(), samplingStatCalculator.getErrorCount());
        Assert.assertEquals(summaryStats.getErrorPercentage().doubleValue(),
                samplingStatCalculator.getErrorPercentage() * 100, 0.1);
        Assert.assertEquals(summaryStats.getThroughput().doubleValue(),
                samplingStatCalculator.getRate(), 0.1);
        Assert.assertEquals(summaryStats.getMin(), samplingStatCalculator.getMin());
        Assert.assertEquals(summaryStats.getMax(), samplingStatCalculator.getMax());
        Assert.assertEquals(summaryStats.getMean().doubleValue(),
                samplingStatCalculator.getMean(), 1.0);
        Assert.assertEquals(summaryStats.getStddev().doubleValue(),
                samplingStatCalculator.getStandardDeviation(), 1.0);
        final double percentileDelta = 10.0D;
        Assert.assertEquals(summaryStats.getP75().doubleValue(),
                samplingStatCalculator.getPercentPoint(0.75).doubleValue(), percentileDelta);
        Assert.assertEquals(summaryStats.getP90().doubleValue(),
                samplingStatCalculator.getPercentPoint(0.90).doubleValue(), percentileDelta);
        Assert.assertEquals(summaryStats.getP95().doubleValue(),
                samplingStatCalculator.getPercentPoint(0.95).doubleValue(), percentileDelta);
        Assert.assertEquals(summaryStats.getP98().doubleValue(),
                samplingStatCalculator.getPercentPoint(0.98).doubleValue(), percentileDelta);
        Assert.assertEquals(summaryStats.getP99().doubleValue(),
                samplingStatCalculator.getPercentPoint(0.99).doubleValue(), percentileDelta);
        Assert.assertEquals(summaryStats.getP999().doubleValue(),
                samplingStatCalculator.getPercentPoint(0.999).doubleValue(), percentileDelta);
        Assert.assertEquals(summaryStats.getReceivedKBytesRate().doubleValue(),
                samplingStatCalculator.getKBPerSecond(), 0.1);
        Assert.assertEquals(summaryStats.getSentKBytesRate().doubleValue(),
                samplingStatCalculator.getSentKBPerSecond(), 0.1);
    }
}
