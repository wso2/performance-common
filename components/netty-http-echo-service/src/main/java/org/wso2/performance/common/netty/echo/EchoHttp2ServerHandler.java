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

import io.netty.buffer.ByteBuf;
import io.netty.buffer.ByteBufUtil;
import io.netty.channel.ChannelDuplexHandler;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.http2.DefaultHttp2DataFrame;
import io.netty.handler.codec.http2.DefaultHttp2Headers;
import io.netty.handler.codec.http2.DefaultHttp2HeadersFrame;
import io.netty.handler.codec.http2.DefaultHttp2WindowUpdateFrame;
import io.netty.handler.codec.http2.Http2DataFrame;
import io.netty.handler.codec.http2.Http2FrameStream;
import io.netty.handler.codec.http2.Http2Headers;
import io.netty.handler.codec.http2.Http2HeadersFrame;
import io.netty.util.CharsetUtil;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static io.netty.buffer.Unpooled.copiedBuffer;
import static io.netty.buffer.Unpooled.unreleasableBuffer;
import static io.netty.buffer.Unpooled.wrappedBuffer;
import static io.netty.handler.codec.http.HttpResponseStatus.OK;

/**
 * Handler implementation for the http2 echo server.
 */
public class EchoHttp2ServerHandler extends ChannelDuplexHandler {

    private static final ByteBuf RESPONSE_BYTES = unreleasableBuffer(copiedBuffer("Hello World", CharsetUtil.UTF_8));
    private static Map dataMap = new ConcurrentHashMap<Integer, ByteBuf>();

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        super.exceptionCaught(ctx, cause);
        ctx.close();
    }

    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        if (msg instanceof Http2HeadersFrame) {
            onHeadersRead(ctx, (Http2HeadersFrame) msg);
        } else if (msg instanceof Http2DataFrame) {
            onDataRead(ctx, (Http2DataFrame) msg);
        } else {
            super.channelRead(ctx, msg);
        }
    }

    @Override
    public void channelReadComplete(ChannelHandlerContext ctx) {
        ctx.flush();
    }

    private static void onDataRead(ChannelHandlerContext ctx, Http2DataFrame data) {
        Http2FrameStream stream = data.stream();

        if (data.isEndStream()) {
            ByteBuf content = (ByteBuf) dataMap.get(stream.id());
            if (content == null) {
                sendResponse(ctx, stream, data.content());
            } else {
                sendResponse(ctx, stream, wrappedBuffer(content, data.content()));
            }
            removeFromMap(stream.id());
        } else {
            addToMap(stream.id(), data.content());
        }

        // Update the flowcontroller
        ctx.write(new DefaultHttp2WindowUpdateFrame(data.initialFlowControlledBytes()).stream(stream));
    }

    private static void addToMap(int streamId, ByteBuf data) {
        ByteBuf content = (ByteBuf) dataMap.get(streamId);
        if (content == null) {
            dataMap.put(streamId, data);
        } else {
            dataMap.put(streamId, wrappedBuffer(content, data));
        }
    }

    private static void removeFromMap(int streamId) {
        ByteBuf content = (ByteBuf) dataMap.get(streamId);
        if (content != null) {
            dataMap.remove(streamId);
        }
    }

    private static void onHeadersRead(ChannelHandlerContext ctx, Http2HeadersFrame headers) {
        if (headers.isEndStream()) {
            ByteBuf content = ctx.alloc().buffer();
            content.writeBytes(RESPONSE_BYTES.duplicate());
            ByteBufUtil.writeAscii(content, " - via HTTP/2");
            sendResponse(ctx, headers.stream(), content);
        }
    }

    private static void sendResponse(ChannelHandlerContext ctx, Http2FrameStream stream, ByteBuf payload) {
        // Send a frame for the response status
        Http2Headers headers = new DefaultHttp2Headers().status(OK.codeAsText());
        ctx.write(new DefaultHttp2HeadersFrame(headers).stream(stream));
        ctx.write(new DefaultHttp2DataFrame(payload, true).stream(stream));
    }
}
