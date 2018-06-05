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
package org.wso2.performance.common.payload.generator;

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

    @Parameter(names = {"-s", "--size"}, description = "Size in bytes (B)", required = true,
            validateWith = PayloadSizeValidator.class)
    private int payloadSize;

    @Parameter(names = {"-t", "--payload-type"}, description = "Type of payload object to generate")
    private PayloadType payloadType = PayloadType.SIMPLE;

    @Parameter(names = "--payload-min-length", description = "Minimum length of payload string in bytes (B). " +
            "Use with --payload-type ARRAY or OBJECT", validateWith = PayloadMinLengthValidator.class)
    private int payloadMinLength = 10;

    @Parameter(names = {"-h", "--help"}, description = "Display Help", help = true)
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
            return;
        }

        if (payloadGenerator.help) {
            jcmdr.usage();
            return;
        }

        payloadGenerator.writePayload();
    }

    private void writePayload() {
        Payload payload;
        switch (payloadType) {
            case SIMPLE:
                payload = new SimplePayload(payloadSize);
                break;
            case ARRAY:
                payload = new ArrayPayload(payloadSize, payloadMinLength);
                break;
            case OBJECT:
                payload = new ObjectPayload(payloadSize, payloadMinLength);
                break;
            default:
                throw new IllegalStateException("Unknown payload type.");
        }
        byte[] payloadBytes = payload.getJson();
        String fileName = MessageFormat.format("{0,number,#}B.json", payloadSize);
        try {
            Files.write(Paths.get(fileName), payloadBytes);
        } catch (IOException e) {
            errorOutput.println(e.getMessage());
        }

        standardOutput.println(MessageFormat.format("Wrote {0} bytes JSON payload file to {1}",
                payloadBytes.length, fileName));
    }

}
