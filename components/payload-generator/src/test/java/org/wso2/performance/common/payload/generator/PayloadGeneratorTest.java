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

import com.google.gson.JsonElement;
import com.google.gson.JsonParser;
import com.google.gson.JsonSyntaxException;
import org.testng.Assert;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.DataProvider;
import org.testng.annotations.Test;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * JSON payload generator tests.
 */
public class PayloadGeneratorTest {

    private PayloadGenerator payloadGenerator;
    private Random random;
    private static final Path TEST_RESOURCES = Paths.get("src/test/resources/test-resources");

    @BeforeClass
    private void init() {
        payloadGenerator = new PayloadGenerator();
        random = new Random();
    }

    @DataProvider(name = "sizes")
    public Object[][] payloadSizes() {
        List<Object[]> payloadSizes = new ArrayList<>(10);
        for (int i = 0; i < 500; i++) {
            payloadSizes.add(new Object[]{50 + i});
        }
        payloadSizes.add(new Object[]{1024});
        payloadSizes.add(new Object[]{10240});
        payloadSizes.add(new Object[]{102400});
        for (int i = 0; i < 100; i++) {
            payloadSizes.add(new Object[]{100 + random.nextInt(102400)});
        }
        return payloadSizes.toArray(new Object[payloadSizes.size()][1]);
    }

    private boolean isValidJson(String json) {
        try {
            JsonElement res = new JsonParser().parse(json);
            if (!res.isJsonObject()) {
                return false;
            }
        } catch (JsonSyntaxException e) {
            return false;
        }
        return true;
    }


    @Test(dataProvider = "sizes")
    private void testSimplePayload(int size) {
        testPayload(new SimplePayload(size).getJson(), size);
    }

    @Test(dataProvider = "sizes")
    private void testArrayPayload(int size) {
        testPayload(new ArrayPayload(size, 10).getJson(), size);
    }

    private void testPayload(byte[] payload, int size) {
        String json = new String(payload);
        Assert.assertFalse(json.matches(".*\"\".*"), "Empty values are not allowed\n" + json);
        Assert.assertTrue(isValidJson(json), "Invalid Json object\n" + json);
        Assert.assertEquals(payload.length, size, "Invalid size\n" + json);
    }


    @DataProvider(name = "simplePayloads")
    public Object[][] simplePayloads() {
        List<Object[]> payloads = new ArrayList<>(10);
        payloads.add(new Object[]{50, "{\"size\":\"50B\",\"payload\":\"0123456789ABCDEFGHIJKLM\"}"});
        payloads.add(new Object[]{100, "{\"size\":\"100B\",\"payload\":" +
                "\"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\"}"});
        payloads.add(new Object[]{150, "{\"size\":\"150B\",\"payload\":" +
                "\"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" +
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwx\"}"});
        return payloads.toArray(new Object[payloads.size()][1]);
    }

    @Test(dataProvider = "simplePayloads")
    private void testSimplePayload(int size, String expected) {
        testPayload(new SimplePayload(size).getJson(), expected);
    }

    @DataProvider(name = "arrayPayloads")
    public Object[][] arrayPayloads() {
        List<Object[]> payloads = new ArrayList<>(10);
        payloads.add(new Object[]{50, "{\"size\":\"50B\",\"payload\":[\"0123456789\",\"ABCDEFGH\"]}"});
        payloads.add(new Object[]{55, "{\"size\":\"55B\",\"payload\":[\"0123456789\",\"ABCDEFGHIJKLM\"]}"});
        payloads.add(new Object[]{56, "{\"size\":\"56B\",\"payload\":[\"0123456789\",\"ABCDEFGHIJ\",\"K\"]}"});
        return payloads.toArray(new Object[payloads.size()][1]);
    }

    @Test(dataProvider = "arrayPayloads")
    private void testArrayPayload(int size, String expected) {
        testPayload(new ArrayPayload(size, 10).getJson(), expected);
    }

    @DataProvider(name = "objectPayloads")
    public Object[][] objectPayloads() {
        List<Object[]> payloads = new ArrayList<>(10);
        payloads.add(new Object[]{50, "{\"size\":\"50B\",\"payload\":{\"payload1\":\"0123456789\"}}"});
        payloads.add(new Object[]{64, "{\"size\":\"64B\",\"payload\":{\"payload1\":\"0123456789ABCDEFGHIJKLMN\"}}"});
        payloads.add(new Object[]{65,
                "{\"size\":\"65B\",\"payload\":{\"payload1\":\"0123456789\",\"payload2\":\"A\"}}"});
        return payloads.toArray(new Object[payloads.size()][1]);
    }

    private void testPayload(byte[] payload, String expected) {
        String json = new String(payload);
        Assert.assertEquals(json, expected, "Unexpected Json\n" + json);
    }

    @Test
    public void tesObjectPayloads() throws IOException {
        int[] objectPayloadSizes = {500, 1000, 10000, 100000};
        for (int size : objectPayloadSizes) {
            String fileName = String.format("%dB.json", size);
            String expected = new String(Files.readAllBytes(TEST_RESOURCES.resolve(fileName)));
            ObjectPayload payload = new ObjectPayload(size, 10);
            String payloadStr = new String(payload.getJson(), StandardCharsets.UTF_8);
            Assert.assertEquals(payloadStr, expected);
        }
    }
}
