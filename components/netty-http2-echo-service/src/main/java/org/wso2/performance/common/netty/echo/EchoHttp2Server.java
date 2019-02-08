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

import com.beust.jcommander.JCommander;
import com.beust.jcommander.Parameter;
import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.Channel;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.handler.codec.http2.Http2SecurityUtil;
import io.netty.handler.ssl.ApplicationProtocolConfig;
import io.netty.handler.ssl.ApplicationProtocolNames;
import io.netty.handler.ssl.SslContext;
import io.netty.handler.ssl.SslContextBuilder;
import io.netty.handler.ssl.SslProvider;
import io.netty.handler.ssl.SupportedCipherSuiteFilter;
import io.netty.handler.ssl.util.SelfSignedCertificate;
import io.netty.util.Version;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLException;

/**
 * Echoes back any received data from an HTTP/HTTP2 client.
 */
public final class EchoHttp2Server {

    private static final Logger logger = LoggerFactory.getLogger(EchoHttp2Server.class);

    @Parameter(names = "--port", description = "Server Port")
    private int port = 8688;

    @Parameter(names = "--boss-threads", description = "Boss Threads")
    private int bossThreads = Runtime.getRuntime().availableProcessors();

    @Parameter(names = "--worker-threads", description = "Worker Threads")
    private int workerThreads = 200;

    @Parameter(names = "--enable-ssl", description = "Enable SSL")
    private boolean enableSSL = false;

    @Parameter(names = "--key-store-file", validateValueWith = KeyStoreFileValidator.class,
            description = "Keystore file")
    private File keyStoreFile = null;

    @Parameter(names = "--key-store-password", description = "Keystore password")
    private String keyStorePassword;

    @Parameter(names = "--sleep-time", description = "Sleep Time in milliseconds")
    private int sleepTime = 0;

    @Parameter(names = {"-h", "--help"}, description = "Display Help", help = true)
    private boolean help = false;

    public static void main(String[] args) throws Exception {
        EchoHttp2Server echoHttp2Server = new EchoHttp2Server();
        final JCommander jcmdr = new JCommander(echoHttp2Server);
        jcmdr.setProgramName(EchoHttp2Server.class.getSimpleName());
        jcmdr.parse(args);

        if (echoHttp2Server.help) {
            jcmdr.usage();
            return;
        }

        echoHttp2Server.startServer();
    }

    private void startServer() throws SSLException, CertificateException, InterruptedException {
        logger.info("Echo HTTP2 Server. Port: {}, Boss Threads: {}, Worker Threads: {}, SSL Enabled: {}" +
                ", Sleep Time: {}ms", port, bossThreads, workerThreads, enableSSL, sleepTime);
        // Print Max Heap Size
        logger.info("Max Heap Size: {}MB", Runtime.getRuntime().maxMemory() / (1024 * 1024));
        // Print Netty Version
        Version version = Version.identify(this.getClass().getClassLoader()).values().iterator().next();
        logger.info("Netty Version: {}", version.artifactVersion());
        // Configure SSL.
        final SslContext sslCtx;
        if (enableSSL) {
            if (keyStoreFile != null) {
                KeyManagerFactory keyManagerFactory = getKeyManagerFactory(keyStoreFile);
                sslCtx = SslContextBuilder.forServer(keyManagerFactory).applicationProtocolConfig(
                        new ApplicationProtocolConfig(ApplicationProtocolConfig.Protocol.ALPN,
                                ApplicationProtocolConfig.SelectorFailureBehavior.NO_ADVERTISE,
                                ApplicationProtocolConfig.SelectedListenerFailureBehavior.ACCEPT,
                                ApplicationProtocolNames.HTTP_2, ApplicationProtocolNames.HTTP_1_1))
                        .sslProvider(SslProvider.OPENSSL)
                        .ciphers(Http2SecurityUtil.CIPHERS, SupportedCipherSuiteFilter.INSTANCE).build();
                logger.info("Ssl context is created from {}", keyStoreFile.getAbsolutePath());
            } else {
                SelfSignedCertificate ssc = new SelfSignedCertificate();
                sslCtx = SslContextBuilder.forServer(ssc.certificate(), ssc.privateKey())
                        .ciphers(Http2SecurityUtil.CIPHERS, SupportedCipherSuiteFilter.INSTANCE)
                        .sslProvider(SslProvider.OPENSSL).applicationProtocolConfig(
                                new ApplicationProtocolConfig(ApplicationProtocolConfig.Protocol.ALPN,
                                        ApplicationProtocolConfig.SelectorFailureBehavior.NO_ADVERTISE,
                                        ApplicationProtocolConfig.SelectedListenerFailureBehavior.ACCEPT,
                                        ApplicationProtocolNames.HTTP_2, ApplicationProtocolNames.HTTP_1_1)).build();
            }
        } else {
            sslCtx = null;
        }
        // Configure the server.
        EventLoopGroup group = new NioEventLoopGroup();
        try {
            ServerBootstrap b = new ServerBootstrap();
            b.option(ChannelOption.SO_BACKLOG, 1024);
            b.group(group)
                    .channel(NioServerSocketChannel.class)
                    .childHandler(new Http2ServerInitializer(sslCtx));

            Channel ch = b.bind(port).sync().channel();
            ch.closeFuture().sync();
        } finally {
            group.shutdownGracefully();
        }
    }

    private KeyManagerFactory getKeyManagerFactory(File keyStoreFile) {
        KeyManagerFactory kmf;
        try {
            KeyStore ks = getKeyStore(keyStoreFile, keyStorePassword);
            kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            if (ks != null) {
                kmf.init(ks, keyStorePassword.toCharArray());
            }
            return kmf;
        } catch (UnrecoverableKeyException | NoSuchAlgorithmException | KeyStoreException | IOException e) {
            throw new IllegalArgumentException("Failed to initialize the Key Manager factory", e);
        }
    }

    private KeyStore getKeyStore(File keyStoreFile, String keyStorePassword) throws IOException {
        KeyStore keyStore = null;
        String  tlsStoreType = "PKCS12";
        if (keyStoreFile != null && keyStorePassword != null) {
            try (InputStream is = new FileInputStream(keyStoreFile)) {
                keyStore = KeyStore.getInstance(tlsStoreType);
                keyStore.load(is, keyStorePassword.toCharArray());
            } catch (CertificateException | NoSuchAlgorithmException | KeyStoreException e) {
                throw new IOException(e);
            }
        }
        return keyStore;
    }
}
