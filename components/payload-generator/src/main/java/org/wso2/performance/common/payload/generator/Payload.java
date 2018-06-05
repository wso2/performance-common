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
package org.wso2.performance.common.payload.generator;

import java.nio.charset.Charset;

/**
 * Generate JSON payload. Subclasses defined the object type and completes the payload.
 */
public abstract class Payload {

    // Characters start with '0'
    protected static final int START_CHAR = '0';

    protected final int payloadSize;

    protected final Charset payloadCharset = Charset.forName("UTF-8");

    public Payload(int payloadSize) {
        this.payloadSize = payloadSize;
    }

    public byte[] getJson() {
        StringBuilder payloadBuilder = new StringBuilder();
        payloadBuilder.append("{\"size\":\"").append(payloadSize).append("B\",\"payload\":");
        generatePayloadObject(payloadBuilder);
        return payloadBuilder.toString().getBytes(payloadCharset);
    }

    protected abstract void generatePayloadObject(StringBuilder payloadBuilder);

    protected char getNextChar(char c) {
        c++;
        if (c - 1 == '9') {
            c = 'A';
        } else if (c - 1 == 'Z') {
            c = 'a';
        } else if (c - 1 == 'z') {
            c = '0';
        }
        return c;
    }

}
