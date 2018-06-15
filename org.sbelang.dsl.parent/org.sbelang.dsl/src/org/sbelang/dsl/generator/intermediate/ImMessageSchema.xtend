package org.sbelang.dsl.generator.intermediate

import org.sbelang.dsl.sbeLangDsl.MessageSchema
import java.nio.ByteOrder
import org.sbelang.dsl.sbeLangDsl.OptionalSchemaAttrs

class ImMessageSchema {
    static val DEFAULT_HEADER_TYPE_NAME = "org.sbelang.DefaultHeader"

    public val MessageSchema rawSchema

    public val String schemaName
    public val int schemaId
    public val int schemaVersion
    public val ByteOrder schemaByteOrder
    public val String schemaByteOrderConstant;
    public val String headerTypeName

    new(MessageSchema rawSchema) {
        this.rawSchema = rawSchema

        this.schemaName = rawSchema.schema.name
        this.schemaId = rawSchema.schema.id
        this.schemaVersion = rawSchema.schema.version
        this.schemaByteOrder = parseByteOrder(rawSchema.schema.optionalAttrs)
        this.schemaByteOrderConstant = if (schemaByteOrder === ByteOrder.BIG_ENDIAN) "BIG_ENDIAN" else "LITTLE_ENDIAN"
        this.headerTypeName = parseHeaderTypeName(rawSchema.schema.optionalAttrs)
    }

    private def parseByteOrder(OptionalSchemaAttrs attrs) {
        if (rawSchema.schema.optionalAttrs === null)
            ByteOrder.LITTLE_ENDIAN
        else if (rawSchema.schema.optionalAttrs.bigEndian)
            ByteOrder.BIG_ENDIAN
        else
            ByteOrder.LITTLE_ENDIAN
    }

    private def parseHeaderTypeName(OptionalSchemaAttrs attrs) {
        if (rawSchema.schema.optionalAttrs === null)
            DEFAULT_HEADER_TYPE_NAME
        else
            rawSchema.schema.optionalAttrs.headerType;
    }
}
