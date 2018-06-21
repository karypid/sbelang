package org.sbelang.dsl.generator

import java.nio.ByteOrder
import org.eclipse.emf.common.util.EList
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.generator.intermediate.ImMessageSchema
import org.sbelang.dsl.sbeLangDsl.CompositeMember
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumValueDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberTypeDeclaration

class SbeLangDslJavaGenerator extends SbeLangDslBaseGenerator {

    public static val genJava = Boolean.valueOf(
        System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genJava", "true"))

    override void compile(ImMessageSchema imSchema, IFileSystemAccess2 fsa, IGeneratorContext context) {
        if(!genJava) return;

        // meta-data for overall message schema
        fsa.generateFile(
            imSchema.filename('MessageSchema.java'),
            generateMessageSchema(imSchema)
        )

        imSchema.fqnEnumsMap.forEach [ enumName, ed |
            System.out.println(enumName + ": " + ed.name)
            fsa.generateFile(imSchema.filename(ed.name.toFirstUpper + ".java"), compileEnum(imSchema, ed))
        ]

        imSchema.fqnCompositesMap.forEach [ compositeName, ctd |
            System.out.println(compositeName + ": " + ctd.name)
            fsa.generateFile(imSchema.filename(ctd.name.toFirstUpper + "Encoder.java"),
                compileCompositeEncoder(imSchema, ctd))
        ]
    }

    private def compileEnum(ImMessageSchema imSchema, EnumDeclaration ed) {
        val enumName = ed.name.toFirstUpper
        val enumValueJavaType = enumJavaType(ed.encodingType)
        '''
            package  «imSchema.schemaName»;
            
            public enum «enumName»
            {
                «FOR ev : ed.enumValues»
                    «ev.name»( («enumValueJavaType») «ev.value» ),
                «ENDFOR»«IF !isEnumWithExplicitNull(ed.enumValues)»
                    NULL_VAL ( («enumValueJavaType») «enumDefaultNullValueLiteral(ed.encodingType)» )
                «ENDIF»
                ;
                
                public final «enumValueJavaType» value;
                
                private «enumName»(«enumValueJavaType» value)
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
        '''
    }

    private def compileCompositeEncoder(ImMessageSchema imSchema, CompositeTypeDeclaration ctd) {
        val compositeName = ctd.name.toFirstUpper + 'Encoder'
        '''
            package  «imSchema.schemaName»;
            
            import org.agrona.MutableDirectBuffer;
            
            public class «compositeName»
            {
                public static final int ENCODED_LENGTH = (-1 /* TODO */);
                
                private int offset;
                private MutableDirectBuffer buffer;

                public «compositeName» wrap(final MutableDirectBuffer buffer, final int offset)
                {
                    this.buffer = buffer;
                    this.offset = offset;
            
                    return this;
                }
            
                public MutableDirectBuffer buffer()
                {
                    return buffer;
                }
            
                public int offset()
                {
                    return offset;
                }
            
                public int encodedLength()
                {
                    return ENCODED_LENGTH;
                }

                «FOR cm : ctd.compositeMembers»
                    «compileEncoderFor(cm)»
                «ENDFOR»
            }
        '''
    }

    private def compileEncoderFor(CompositeMember cm) {
        switch cm {
            CompositeTypeDeclaration:
                compileEncoderFor(cm)
            MemberTypeDeclaration:
                compileEncoderFor(cm)
            default: '''// Not implemented yet'''
        }
    }

    private def compileEncoderFor(CompositeTypeDeclaration cm) {
        val encoderClassSimpleName = cm.name.toFirstUpper + 'Encoder'
        val encoderVarName = cm.name
        '''
            // «encoderClassSimpleName»
            private «encoderClassSimpleName» «encoderVarName» = new «encoderClassSimpleName»();
            
            public «encoderClassSimpleName» «encoderVarName»()
            {
                «encoderVarName».wrap(buffer, offset + (-1 /* TODO */) );
                return «encoderVarName»;
            }
            
        '''
    }

    private def compileEncoderFor(MemberTypeDeclaration cm) {
        '''
        '''
    }

    private def enumDefaultNullValueLiteral(String enumEncodingType) {
        switch (enumEncodingType) {
            case 'char': '0'
            case 'uint8': '255'
            case 'uint16': '65535'
            default: throw new IllegalStateException("Encoding not supported for enums: " + enumEncodingType)
        }
    }

    private def boolean isEnumWithExplicitNull(EList<EnumValueDeclaration> enumValues) {
        enumValues.exists[evd|evd.name == "NULL_VAL"]
    }

    private def enumJavaType(String sbePrimitive) {
        switch sbePrimitive {
            case 'char': 'byte'
            case 'uint8': 'short'
            case 'uint16': 'int'
            default: throw new IllegalArgumentException('No enum mapping for: ' + sbePrimitive)
        }
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
