/*
 * Copyright 2017 WSO2 Inc. (http://wso2.org)
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

import com.beust.jcommander.JCommander;
import com.beust.jcommander.Parameter;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Path;
import java.text.MessageFormat;
import java.util.StringTokenizer;
import java.util.concurrent.TimeUnit;

/**
 * Split JTL results file into warmup and measurement.
 */
public final class JTLSplitter {

    @Parameter(names = {"-t", "--warmup-time"}, description = "Warmup Time", required = true,
            validateWith = WarmupTimeValidator.class)
    private int warmupTime;

    @Parameter(names = {"-u", "--time-unit"}, description = "Time Unit")
    private TimeUnit timeUnit = TimeUnit.MINUTES;

    @Parameter(names = {"-f", "--jtlfile"}, description = "JTL File", required = true,
            validateValueWith = JTLFileValidator.class)
    private File jtlFile;

    @Parameter(names = {"-d", "--delete-jtl-file-on-exit"}, description = "Delete JTL File on exit")
    private boolean deleteJTLFileOnExit;

    @Parameter(names = {"-h", "--help"}, description = "Display Help", help = true)
    private boolean help = false;

    private static PrintStream errorOutput = System.err;
    private static PrintStream standardOutput = System.out;

    public static void main(String[] args) {
        JTLSplitter jtlSplitter = new JTLSplitter();
        final JCommander jcmdr = new JCommander(jtlSplitter);
        jcmdr.setProgramName(JTLSplitter.class.getSimpleName());

        try {
            jcmdr.parse(args);
        } catch (Exception e) {
            errorOutput.println(e.getMessage());
            return;
        }

        if (jtlSplitter.help) {
            jcmdr.usage();
            return;
        }

        jtlSplitter.splitJTL();
    }

    private void splitJTL() {
        long startTime = System.nanoTime();
        Path jtlPath = jtlFile.toPath();
        String fileName = jtlPath.getFileName().toString();
        String outputFileFormat = fileName.substring(0, fileName.length() - 4).concat("-{0}.jtl");
        Path warmupJTLFile = jtlPath.resolveSibling(MessageFormat.format(outputFileFormat, "warmup"));
        Path measurementJTLFile = jtlPath.resolveSibling(MessageFormat.format(outputFileFormat, "measurement"));

        standardOutput.format("Splitting %s file into %s and %s.%n", fileName, warmupJTLFile.getFileName(),
                measurementJTLFile.getFileName());
        standardOutput.format("Warmup Time: %d %s%n", warmupTime, timeUnit);

        long timeLimit = timeUnit.toMillis(warmupTime);

        try (BufferedReader br = new BufferedReader(new FileReader(jtlFile));
             BufferedWriter bwWarmup = new BufferedWriter(new FileWriter(warmupJTLFile.toFile()));
             BufferedWriter bwMeasurement = new BufferedWriter(new FileWriter(measurementJTLFile.toFile()))) {
            // Read header
            String line = br.readLine();
            if (line != null) {
                // Write Header
                bwWarmup.write(line);
                bwWarmup.newLine();
                bwMeasurement.write(line);
                bwMeasurement.newLine();
            }

            // Read first line with data
            line = br.readLine();
            if (line == null) {
                return;
            }

            StringTokenizer st = new StringTokenizer(line, ",", false);
            long startTimestamp = Long.parseLong(st.nextToken());

            // Current Line Number
            long lineNumber = 2;
            standardOutput.print("Started splitting...\r");

            do {
                st = new StringTokenizer(line, ",", false);
                if (lineNumber % 10_000 == 0) {
                    standardOutput.print("Processed " + lineNumber + " lines.\r");
                }
                // Validate token count
                // JTL file usually has 16 columns
                if (st.countTokens() > 16) {
                    errorOutput.format("Line %d doesn't have expected number of columns: %s%n", lineNumber, line);
                    continue;
                }
                long timestamp = Long.parseLong(st.nextToken());
                long diff = timestamp - startTimestamp;
                if (diff <= timeLimit) {
                    bwWarmup.write(line);
                    bwWarmup.newLine();
                } else {
                    bwMeasurement.write(line);
                    bwMeasurement.newLine();
                }
                lineNumber++;
            } while ((line = br.readLine()) != null);

            // Delete only if splitting is successful
            if (deleteJTLFileOnExit) {
                jtlFile.deleteOnExit();
            }
        } catch (IOException e) {
            errorOutput.println(e.getMessage());
        } finally {
            long elapsed = System.nanoTime() - startTime;
            // Add whitespace to clear progress information
            standardOutput.format("Done in %d min, %d sec.                           %n",
                    TimeUnit.NANOSECONDS.toMinutes(elapsed),
                    TimeUnit.NANOSECONDS.toSeconds(elapsed) -
                            TimeUnit.MINUTES.toSeconds(TimeUnit.NANOSECONDS.toMinutes(elapsed))
            );
        }


    }
}
