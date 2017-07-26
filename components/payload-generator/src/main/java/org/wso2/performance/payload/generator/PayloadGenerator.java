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
package org.wso2.performance.payload.generator;

import com.beust.jcommander.JCommander;
import com.beust.jcommander.Parameter;

import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.text.MessageFormat;

/**
 * Generate a JSON payload for a given size
 */
public final class PayloadGenerator {

    @Parameter(names = "--size", description = "Size in Kibibytes (KiB)", required = true,
            validateWith = PayloadSizeValidator.class)
    private int payloadSize;

    @Parameter(names = "--help", description = "Display Help", help = true)
    private boolean help = false;

    private static PrintStream errorOutput = System.err;
    private static PrintStream standardOutput = System.out;

    public static void main(String[] args) {
        PayloadGenerator payloadGenerator = new PayloadGenerator();
        final JCommander jcmdr = new JCommander(payloadGenerator);
        jcmdr.setProgramName(PayloadGenerator.class.getSimpleName());

        try {
            jcmdr.parse(args);
        } catch (Exception e) {
            errorOutput.println(e.getMessage());
        }

        if (payloadGenerator.help) {
            jcmdr.usage();
            return;
        }

        payloadGenerator.generatePayload();
    }

    private void generatePayload() {
        StringBuilder payloadBuilder = new StringBuilder();
        payloadBuilder.append('{').append('"').append("size").append('"');
        payloadBuilder.append(':').append('"').append(payloadSize).append('K').append('"');
        payloadBuilder.append(',').append('"').append("payload").append('"');
        payloadBuilder.append(':').append('"');

        int limit = payloadSize * 1024 - (payloadBuilder.toString().getBytes().length + 2);

        int c = '0';
        for (int i = 0; i < limit; i++) {
            payloadBuilder.append((char) c);
            if (c == '9') {
                c = 'A' - 1;
            } else if (c == 'Z') {
                c = 'a' - 1;
            } else if (c == 'z') {
                c = '0' - 1;
            }
            c++;
        }

        payloadBuilder.append('"').append('}');

        byte[] payloadBytes = payloadBuilder.toString().getBytes();
        String fileName = MessageFormat.format("{0}K.json", payloadSize);
        try {
            Files.write(Paths.get(fileName), payloadBytes);
        } catch (IOException e) {
            errorOutput.println(e.getMessage());
        }

        standardOutput.println(MessageFormat.format("Wrote {0} bytes ({1} KiB) JSON payload file to {2}",
                payloadBytes.length, payloadBytes.length / 1024, fileName));
    }
}
