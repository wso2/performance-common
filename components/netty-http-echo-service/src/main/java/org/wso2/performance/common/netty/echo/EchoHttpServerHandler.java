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
import io.netty.handler.codec.http2.InboundHttp2ToHttpAdapter;

import static io.netty.handler.codec.http.HttpResponseStatus.OK;
import static io.netty.handler.codec.http.HttpVersion.HTTP_1_1;

/**
 * Handler implementation for the echo server and http/2 echo server with message aggregation.
 * For http/2 echo server with message aggregation, this receives a {@link FullHttpRequest},
 * which has been converted by a {@link InboundHttp2ToHttpAdapter} before it arrived here.
 * For further details, check {@link Http2OrHttpHandler} where the pipeline is setup.
 */
@Sharable
public class EchoHttpServerHandler extends SimpleChannelInboundHandler<FullHttpRequest> {

    private long sleepTime;
    private boolean h2Aggregation;

    EchoHttpServerHandler(long sleepTime, boolean h2Aggregation) {
        this.sleepTime = sleepTime;
        this.h2Aggregation = h2Aggregation;
    }

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, FullHttpRequest request) {
        if (sleepTime > 0) {
            try {
                Thread.sleep(sleepTime);
            } catch (InterruptedException e) {
                // Ignore
            }
        }

        if (h2Aggregation) {
            String streamId = getStreamId(request);
            FullHttpResponse response = EchoHttpServerHandler.buildFullHttpResponse(request);
            setStreamId(response, streamId);
            ctx.write(response);
        } else {
            boolean keepAlive = HttpUtil.isKeepAlive(request);
            FullHttpResponse response = buildFullHttpResponse(request);
            if (!keepAlive) {
                ctx.write(response).addListener(ChannelFutureListener.CLOSE);
            } else {
                response.headers().set(HttpHeaderNames.CONNECTION, HttpHeaderValues.KEEP_ALIVE);
                ctx.write(response);
            }
        }
    }

    @Override
    public void channelReadComplete(ChannelHandlerContext ctx) {
        ctx.flush();
    }

    private static FullHttpResponse buildFullHttpResponse(FullHttpRequest request) {
        FullHttpResponse response = new DefaultFullHttpResponse(HTTP_1_1, OK, request.content().copy());
        String contentType = request.headers().get(HttpHeaderNames.CONTENT_TYPE);
        if (contentType != null) {
            response.headers().set(HttpHeaderNames.CONTENT_TYPE, contentType);
        }
        response.headers().setInt(HttpHeaderNames.CONTENT_LENGTH, response.content().readableBytes());
        return response;
    }

    private String getStreamId(FullHttpRequest request) {
        return request.headers().get(HttpConversionUtil.ExtensionHeaderNames.STREAM_ID.text());
    }

    private void setStreamId(FullHttpResponse response, String streamId) {
        response.headers().set(HttpConversionUtil.ExtensionHeaderNames.STREAM_ID.text(), streamId);
    }
}
