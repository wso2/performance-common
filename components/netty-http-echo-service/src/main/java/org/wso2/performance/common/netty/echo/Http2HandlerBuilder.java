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

import io.netty.handler.codec.http2.AbstractHttp2ConnectionHandlerBuilder;
import io.netty.handler.codec.http2.Http2ConnectionDecoder;
import io.netty.handler.codec.http2.Http2ConnectionEncoder;
import io.netty.handler.codec.http2.Http2Settings;

/**
 * Handler builder for HTTP2 handler.
 */
public final class Http2HandlerBuilder
        extends AbstractHttp2ConnectionHandlerBuilder<EchoHttp2ServerHandler, Http2HandlerBuilder> {

    @Override
    public EchoHttp2ServerHandler build() {
        return super.build();
    }

    @Override
    protected EchoHttp2ServerHandler build(Http2ConnectionDecoder decoder, Http2ConnectionEncoder encoder,
                                           Http2Settings initialSettings) {
        EchoHttp2ServerHandler handler = new EchoHttp2ServerHandler(decoder, encoder, initialSettings);
        frameListener(handler);
        return handler;
    }
}
