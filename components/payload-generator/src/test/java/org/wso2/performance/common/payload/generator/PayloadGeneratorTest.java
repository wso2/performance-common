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

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * JSON payload generator tests.
 */
public class PayloadGeneratorTest {

    private PayloadGenerator payloadGenerator;
    private Random random;

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

    @Test(dataProvider = "sizes")
    private void testObjectPayload(int size) {
        testPayload(new ObjectPayload(size, 10).getJson(), size);
    }

    private void testPayload(byte[] payload, int size) {
        String json = new String(payload);
        Assert.assertFalse(json.matches(".*\"\".*"), "Empty values are not allowed\n" + json);
        Assert.assertTrue(isValidJson(json), "Invalid Json object\n" + json);
        Assert.assertEquals(payload.length, size, "Invalid size\n" + json);
    }
}
