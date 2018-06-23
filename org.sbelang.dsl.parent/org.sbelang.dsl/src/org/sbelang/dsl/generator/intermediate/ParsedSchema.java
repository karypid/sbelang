/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import org.sbelang.dsl.sbeLangDsl.MessageSchema;

/**
 * @author karypid
 *
 */
public class ParsedSchema
{
    private final MessageSchema rawSchema;

    ParsedSchema(MessageSchema rawSchema)
    {
        this.rawSchema = rawSchema;
    }

    /**
     * @return the rawSchema
     */
    public MessageSchema getRawSchema()
    {
        return rawSchema;
    }
}
