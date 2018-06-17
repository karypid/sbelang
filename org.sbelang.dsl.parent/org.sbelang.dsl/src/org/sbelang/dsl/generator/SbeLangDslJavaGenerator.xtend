package org.sbelang.dsl.generator

import java.nio.ByteOrder
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.generator.intermediate.ImMessageSchema
import org.sbelang.dsl.sbeLangDsl.EnumValueDeclaration
import org.eclipse.emf.common.util.EList

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

    private def enumJavaType(String sbePrimitive) {
        switch sbePrimitive {
            case 'char' : 'byte'
            case 'uint8': 'short'
            case 'uint16': 'int'
            default: throw new IllegalArgumentException('No enum mapping for: ' + sbePrimitive)
        }
    }

    private def generateEnums(IFileSystemAccess2 fsa, ImMessageSchema imSchema) {
        imSchema.enumDeclarations.forEach [ ed |
            val enumValueJavaType = enumJavaType(ed.encodingType)
            val enumName = ed.name
            fsa.generateFile(imSchema.filename(ed.name + ".java"), '''
                package  «imSchema.schemaName»;
                public enum «enumName»
                {
                    «FOR ev : ed.enumValues»
                        «ev.name»( («enumValueJavaType») «ev.value» ),
                    «ENDFOR»«IF !hasExplicitNull(ed.enumValues)»
                        NULL_VAL ( («enumValueJavaType») «defaultNullValue(ed.encodingType)» )
                    «ENDIF»
                    ;
                    
                    public final «enumValueJavaType» value;
                    
                    private «ed.name»(«enumValueJavaType» value)
                    {
                        this.value = value;
                    }
                    
                    public «enumValueJavaType» value()
                    {
                        return value;
                    }
                    
                    public static «enumName» get ( «enumValueJavaType» value )
                    {
                        switch ( value )
                        {
                            «FOR ev : ed.enumValues»
                            case «ev.value»: return «ev.name»;
                            «ENDFOR»
                            default:
                                throw new IllegalArgumentException ( "Unknown value: " + value );
                        }
                    }
                }
            ''')
        ]
    }

    private def defaultNullValue(String enumEncodingType) {
        switch (enumEncodingType) {
            case 'char': '0'
            case 'uint8': '255'
            case 'uint16': '65535'
            default: throw new IllegalStateException("Encoding not supported for enums: " + enumEncodingType)
        }
    }

    private def boolean hasExplicitNull(EList<EnumValueDeclaration> enumValues) {
        enumValues.exists[evd|evd.name == "NULL_VAL"]
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
