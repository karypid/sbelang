package org.sbelang.dsl.generator

import java.nio.file.Paths
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.generator.intermediate.ImMessageSchema
import org.sbelang.dsl.sbeLangDsl.MessageSchema
import java.io.File
import java.nio.file.Path
import java.nio.ByteOrder

class SbeLangDslJavaGenerator extends SbeLangDslBaseGenerator {

    public static val genJava = Boolean.valueOf(
        System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genJava", "true"))

    override void compile(ImMessageSchema schema, IFileSystemAccess2 fsa, IGeneratorContext context) {
        if(!genJava) return;

        val Path packagePath = {
            val String[] components = schema.schemaName.split("\\.")
            val schemaPath = Paths.get(".", components)
            Paths.get(".").relativize(schemaPath).normalize
        }

        // meta-data for overall message schema
        fsa.generateFile(
            packagePath.toString + File.separatorChar + 'MessageSchema.java',
            generateMessageSchema(schema)
        )
    }

    def generateMessageSchema(ImMessageSchema imSchema) {
        val schemaByteOrderConstant = if(imSchema.schemaByteOrder ===
                ByteOrder.BIG_ENDIAN) "BIG_ENDIAN" else "LITTLE_ENDIAN"
        '''
            package  «imSchema.schemaName»;
            
            import java.nio.ByteOrder;
            
            public class MessageSchema {
                public static final int SCHEMA_ID = «imSchema.schemaId»;
                public static final int SCHEMA_VERSION = «imSchema.schemaVersion»;
                public static final ByteOrder BYTE_ORDER = ByteOrder.«schemaByteOrderConstant»;
            }
        '''
    }
}
