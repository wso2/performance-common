/*
 * Copyright (c) 2019, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package org.wso2.performance.common.netty.echo;

import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.http.HttpObjectAggregator;
import io.netty.handler.codec.http.HttpServerCodec;
import io.netty.handler.codec.http2.DefaultHttp2Connection;
import io.netty.handler.codec.http2.Http2FrameCodecBuilder;
import io.netty.handler.codec.http2.HttpToHttp2ConnectionHandlerBuilder;
import io.netty.handler.codec.http2.InboundHttp2ToHttpAdapter;
import io.netty.handler.codec.http2.InboundHttp2ToHttpAdapterBuilder;
import io.netty.handler.ssl.ApplicationProtocolNames;
import io.netty.handler.ssl.ApplicationProtocolNegotiationHandler;

/**
 * Negotiates with the client if HTTP2 or HTTP is going to be used. Once decided, the
 * pipeline is setup with the correct handlers for the selected protocol.
 */
public class Http2OrHttpHandler extends ApplicationProtocolNegotiationHandler {

    private static final int MAX_CONTENT_LENGTH = 1024 * 100;
    private final long sleepTime;
    private final boolean h2AggregateContent;

    Http2OrHttpHandler(long sleepTime, boolean h2AggregateContent) {
        super(ApplicationProtocolNames.HTTP_1_1);
        this.sleepTime = sleepTime;
        this.h2AggregateContent = h2AggregateContent;
    }

    @Override
    protected void configurePipeline(ChannelHandlerContext ctx, String protocol) {
        if (ApplicationProtocolNames.HTTP_2.equals(protocol)) {

            if (h2AggregateContent) {
                DefaultHttp2Connection connection = new DefaultHttp2Connection(true);
                InboundHttp2ToHttpAdapter listener = new InboundHttp2ToHttpAdapterBuilder(connection)
                        .propagateSettings(true)
                        .validateHttpHeaders(false)
                        .maxContentLength(MAX_CONTENT_LENGTH).build();
                ctx.pipeline().addLast(new HttpToHttp2ConnectionHandlerBuilder()
                        .frameListener(listener)
                        .connection(connection).build());
                ctx.pipeline().addLast(new EchoHttpServerHandler(sleepTime, true));
            } else {
                ctx.pipeline()
                        .addLast(Http2FrameCodecBuilder.forServer().build(), new EchoHttp2ServerHandler(sleepTime));
            }
            return;
        }

        if (ApplicationProtocolNames.HTTP_1_1.equals(protocol)) {
            ctx.pipeline().addLast(new HttpServerCodec(),
                    new HttpObjectAggregator(MAX_CONTENT_LENGTH),
                    new EchoHttpServerHandler(sleepTime, false));
            return;
        }

        throw new IllegalStateException("Unknown protocol: " + protocol);
    }
}
