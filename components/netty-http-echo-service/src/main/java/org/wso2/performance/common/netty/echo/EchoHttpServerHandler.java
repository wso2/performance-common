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
package org.wso2.performance.common.netty.echo;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.SimpleChannelInboundHandler;
import io.netty.handler.codec.http.DefaultFullHttpResponse;
import io.netty.handler.codec.http.FullHttpRequest;
import io.netty.handler.codec.http.FullHttpResponse;
import io.netty.handler.codec.http.HttpHeaderNames;
import io.netty.handler.codec.http.HttpHeaderValues;
import io.netty.handler.codec.http.HttpUtil;
import io.netty.handler.codec.http2.HttpConversionUtil;
import io.netty.util.CharsetUtil;

import java.util.concurrent.TimeUnit;

import static io.netty.handler.codec.http.HttpResponseStatus.OK;
import static io.netty.handler.codec.http.HttpVersion.HTTP_1_1;

/**
 * Handler implementation for the echo server and http/2 echo server with content aggregation.
 * For http/2 echo server with content aggregation, this receives a {@link FullHttpRequest},
 * which has been converted by a {@link io.netty.handler.codec.http2.InboundHttp2ToHttpAdapter} before it arrives here.
 * For further details, check {@link Http2OrHttpHandler} where the pipeline is setup.
 */
@Sharable
public class EchoHttpServerHandler extends SimpleChannelInboundHandler<FullHttpRequest> {

    private long sleepTime;
    private boolean h2ContentAggregate;

    EchoHttpServerHandler(long sleepTime, boolean h2ContentAggregate) {
        this.sleepTime = sleepTime;
        this.h2ContentAggregate = h2ContentAggregate;
    }

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, FullHttpRequest request) {
        if (h2ContentAggregate) {
            String streamId = request.headers().get(HttpConversionUtil.ExtensionHeaderNames.STREAM_ID.text());
            FullHttpResponse response = buildFullHttpResponse(request);
            response.headers().set(HttpConversionUtil.ExtensionHeaderNames.STREAM_ID.text(), streamId);
            ctx.writeAndFlush(response);
        } else {
            // Decide whether to close the connection or not
            boolean keepAlive = HttpUtil.isKeepAlive(request);
            // Build the response object
            FullHttpResponse response = buildFullHttpResponse(request);
            if (keepAlive) {
                // Add keep alive header
                response.headers().set(HttpHeaderNames.CONNECTION, HttpHeaderValues.KEEP_ALIVE);
            }
            if (sleepTime > 0) {
                ctx.executor().schedule(() -> {
                    ChannelFuture f = ctx.writeAndFlush(response);
                    if (!keepAlive) {
                        f.addListener(ChannelFutureListener.CLOSE);
                    }
                }, sleepTime, TimeUnit.MILLISECONDS);
            } else {
                ChannelFuture f = ctx.writeAndFlush(response);
                if (!keepAlive) {
                    f.addListener(ChannelFutureListener.CLOSE);
                }
            }
        }
    }

    private static FullHttpResponse buildFullHttpResponse(FullHttpRequest request) {
//        String[] responseList = EchoHttpServer.GQL_QUERY_RESPONSES;
//        int queryNumber = Integer.parseInt(request.headers().get("query-number"));
//        String responseBody = responseList[queryNumber - 1];
        String responseBody = "{\n" + "  \"data\": {\n" + "    \"hero\": {\n" + "      \"id\": \"2001\",\n"
                + "      \"name\": \"R2-D2\",\n" + "      \"friends\": [\n" + "        {\n"
                + "          \"id\": \"1000\",\n" + "          \"name\": \"Luke Skywalker\",\n"
                + "          \"appearsIn\": [\n" + "            \"NEWHOPE\",\n" + "            \"EMPIRE\",\n"
                + "            \"JEDI\"\n" + "          ]\n" + "        },\n" + "        {\n"
                + "          \"id\": \"1002\",\n" + "          \"name\": \"Han Solo\",\n"
                + "          \"appearsIn\": [\n" + "            \"NEWHOPE\",\n" + "            \"EMPIRE\",\n"
                + "            \"JEDI\"\n" + "          ]\n" + "        },\n" + "        {\n"
                + "          \"id\": \"1003\",\n" + "          \"name\": \"Leia Organa\",\n"
                + "          \"appearsIn\": [\n" + "            \"NEWHOPE\",\n" + "            \"EMPIRE\",\n"
                + "            \"JEDI\"\n" + "          ]\n" + "        }\n" + "      ],\n"
                + "      \"friendsConnection\": {\n" + "        \"totalCount\": 3\n" + "      },\n"
                + "      \"appearsIn\": [\n" + "        \"NEWHOPE\",\n" + "        \"EMPIRE\",\n" + "        \"JEDI\"\n"
                + "      ]\n" + "    }\n" + "  }\n" + "}";

        // Return the response depending on the query-number header value
        ByteBuf content = Unpooled.copiedBuffer(
                responseBody,
                CharsetUtil.UTF_8
        );
        FullHttpResponse response = new DefaultFullHttpResponse(HTTP_1_1, OK, content);
        String contentType = request.headers().get(HttpHeaderNames.CONTENT_TYPE);
        if (contentType != null) {
            response.headers().set(HttpHeaderNames.CONTENT_TYPE, contentType);
        }
        response.headers().setInt(HttpHeaderNames.CONTENT_LENGTH, response.content().readableBytes());
        return response;
    }
}
