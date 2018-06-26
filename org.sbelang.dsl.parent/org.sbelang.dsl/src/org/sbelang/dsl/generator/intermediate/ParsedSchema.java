/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import java.nio.ByteOrder;
import java.util.Map;

import org.sbelang.dsl.sbeLangDsl.MessageSchema;
import org.sbelang.dsl.sbeLangDsl.OptionalSchemaAttrs;
import org.sbelang.dsl.sbeLangDsl.TypeDeclaration;

import com.google.common.collect.ImmutableMap;

/**
 * @author karypid
 *
 */
public class ParsedSchema
{
    public static final String DEFAULT_HEADER_TYPE_NAME = "messageHeader";

    private final MessageSchema                         messageSchema;
    private final ImmutableMap<String, TypeDeclaration> allRootNames;
    private final ImmutableMap<String, ParsedComposite> allParsedComposites;

    private final int       schemaId;
    private final String    schemaName;
    private final int       schemaVersion;
    private final ByteOrder schemaByteOrder;
    private final String    schemaHeaderType;

    public ParsedSchema(MessageSchema messageSchema, Map<String, TypeDeclaration> allRootNames,
                    Map<String, ParsedComposite> allParsedComposites)
    {
        this.messageSchema = messageSchema;
        this.allRootNames = ImmutableMap.copyOf(allRootNames);
        this.allParsedComposites = ImmutableMap.copyOf(allParsedComposites);

        OptionalSchemaAttrs schemaOptionalAttrs = messageSchema.getSchema().getOptionalAttrs();
        this.schemaByteOrder = ((schemaOptionalAttrs == null)
                        || (!schemaOptionalAttrs.isBigEndian())) ? ByteOrder.LITTLE_ENDIAN
                                        : ByteOrder.BIG_ENDIAN;
        this.schemaHeaderType = (schemaOptionalAttrs == null) ? null
                        : schemaOptionalAttrs.getHeaderType();

        this.schemaId = messageSchema.getSchema().getId();
        this.schemaName = messageSchema.getSchema().getName();
        this.schemaVersion = messageSchema.getSchema().getVersion();
    }

    public MessageSchema getMessageSchema()
    {
        return messageSchema;
    }

    public String getSchemaName()
    {
        return schemaName;
    }

    public int getSchemaId()
    {
        return schemaId;
    }

    public int getSchemaVersion()
    {
        return schemaVersion;
    }

    public String getSchemaHeaderType()
    {
        return schemaHeaderType;
    }

    public ByteOrder getSchemaByteOrder()
    {
        return schemaByteOrder;
    }
}
