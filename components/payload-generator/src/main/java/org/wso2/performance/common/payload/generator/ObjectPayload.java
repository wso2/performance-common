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

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;

/**
 * Generate a payload object with multiple members.
 */
public class ObjectPayload extends Payload {

//    private final int payloadMinLength;

    public ObjectPayload(int payloadSize, int payloadMinLength) {
        super(payloadSize);
//        this.payloadMinLength = payloadMinLength;
    }

    @Override
    protected void generatePayloadObject(StringBuilder payloadBuilder) {
        JsonObject jsonPayload = getOrderObject();
        payloadBuilder.append(jsonPayload);
        payloadBuilder.append("}");
    }

    private JsonObject getOrderObject() {
        JsonObject orderObj = new JsonObject();
        orderObj.addProperty("symbol", "MSFT");
        orderObj.addProperty("buyerID", "doe");
        orderObj.addProperty("price", 23.56);
        orderObj.addProperty("volume", 8400);
        JsonArray ordersArray = new JsonArray();
        ordersArray.add(orderObj);

        while (ordersArray.toString().getBytes(payloadCharset).length < payloadSize) {
            ordersArray.add(orderObj);
        }

        JsonObject finalObj = new JsonObject();
        finalObj.addProperty("symbol", "GOOG");
        finalObj.addProperty("buyerID", "jim");
        finalObj.addProperty("price", 42.8);
        finalObj.addProperty("volume", 5000);
        ordersArray.add(finalObj);

        JsonObject jsonPayload = new JsonObject();
        jsonPayload.add("order", ordersArray);
        return jsonPayload;
    }
}
