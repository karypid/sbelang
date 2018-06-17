package org.sbelang.dsl.generator

import java.nio.ByteOrder
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.generator.intermediate.ImMessageSchema

class SbeLangDslJavaGenerator extends SbeLangDslBaseGenerator {

    public static val genJava = Boolean.valueOf(
        System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genJava", "true"))

    override void compile(ImMessageSchema schema, IFileSystemAccess2 fsa, IGeneratorContext context) {
        if(!genJava) return;

        // meta-data for overall message schema
        fsa.generateFile(
            schema.filename('MessageSchema.java'),
            generateMessageSchema(schema)
        )

        generateEnums(fsa, schema)
    }

    private def javaType(String sbePrimitive) {
        switch sbePrimitive {
            case 'char',
            case 'float',
            case 'double' : sbePrimitive
            case 'int8': 'byte'
            case 'int16': 'short'
            case 'int32': 'int'
            case 'int64': 'long'
            case 'uint8': 'byte'
            case 'uint16': 'short'
            case 'uint32': 'int'
            case 'uint64': 'long'
            default: throw new IllegalArgumentException('No mapping for: ' + sbePrimitive)
        }
    }

    private def generateEnums(IFileSystemAccess2 fsa, ImMessageSchema imSchema) {
        imSchema.enumDeclarations.forEach [ ed |
            val enumValueJavaType = javaType(ed.encodingType)
            fsa.generateFile(imSchema.filename(ed.name + ".java"), '''
                package  «imSchema.schemaName»;
                public enum «ed.name» {
                    «FOR ev : ed.enumValues»
                        «ev.name»(«ev.value»),
                    «ENDFOR»
                    ;
                    
                    public final «enumValueJavaType» value;
                    
                    private «ed.name»(«enumValueJavaType» value) {
                        this.value = value;
                    }
                }
            ''')
        ]
    }

    private def generateMessageSchema(ImMessageSchema imSchema) {
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
