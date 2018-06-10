package org.sbelang.dsl.generator.xml

import org.sbelang.dsl.generator.intermediate.ImMessageSchema
import java.nio.ByteOrder

class XmlMessageSchema {
    public val ImMessageSchema imSchema
    
    public val String byteOrderAttribute

    new(ImMessageSchema imSchema) {
        this.imSchema = imSchema;

        this.byteOrderAttribute = if(imSchema.schemaByteOrder ===
            ByteOrder.LITTLE_ENDIAN) "littleEndian" else "bigEndian";
    }
}
