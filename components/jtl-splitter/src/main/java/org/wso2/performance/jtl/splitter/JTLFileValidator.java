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
package org.wso2.performance.jtl.splitter;

import com.beust.jcommander.IValueValidator;
import com.beust.jcommander.ParameterException;

import java.io.File;

/**
 * Validate JTL file extension
 */
public class JTLFileValidator implements IValueValidator<File> {

    @Override
    public void validate(String name, File file) throws ParameterException {
        String fileName = file.toPath().getFileName().toString();
        String ext = fileName.substring(fileName.lastIndexOf('.') + 1);
        if (!file.exists() || !"jtl".equals(ext)) {
            throw new ParameterException("Parameter " + name + " should be a valid JTL file");
        }
    }
}

