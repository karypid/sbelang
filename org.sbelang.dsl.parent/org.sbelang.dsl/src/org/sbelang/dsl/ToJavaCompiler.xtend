/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl

import java.io.File
import java.nio.ByteOrder
import org.eclipse.emf.common.util.EList
import org.sbelang.dsl.generator.intermediate.ImMessageSchema
import org.sbelang.dsl.sbeLangDsl.CompositeMember
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumValueDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberTypeDeclaration

/**
 * @author karypid
 * 
 */
class ToJavaCompiler {
    val ImMessageSchema imSchema

    new(ImMessageSchema imSchema) {
        this.imSchema = imSchema
    }

    def generateMessageSchema() {
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

    def generateCompositeEncoder(CompositeTypeDeclaration ctd) {
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
                    «generateCompositeEncoderMember(ctd, cm)»
                «ENDFOR»
            }
        '''
    }

    private def generateCompositeEncoderMember(CompositeTypeDeclaration ownerComposite, CompositeMember member) {
        switch member {
            CompositeTypeDeclaration:
                generateCompositeEncoderMember(ownerComposite, member)
            MemberTypeDeclaration: {
                ''' /* TODO: «member.toString» */'''
            }
            default: {
                ''' /* NOT IMPLEMENTED YET: «member.toString» */'''
            }
        }
    }

    private def generateCompositeEncoderMember(CompositeTypeDeclaration ownerComposite,
        CompositeTypeDeclaration member) {

        val memberEncoderClass = member.name.toFirstUpper + 'Encoder'
        val meberVarName = member.name.toFirstLower
        val fieldIndex = imSchema.getFieldIndex(ownerComposite.name)

        '''
            // «memberEncoderClass»
            public static int «meberVarName»EncodingOffset()
            {
                return («fieldIndex.getOffset(member.name)»);
            }
            
            public static int «meberVarName»EncodingLength()
            {
                return («fieldIndex.getLength(member.name)»);
            }
            
            private «memberEncoderClass» «meberVarName» = new «memberEncoderClass»();
            
            public «memberEncoderClass» «meberVarName»()
            {
                «meberVarName».wrap(buffer, offset + (-1 /* TODO */) );
                return «meberVarName»;
            }
            
        '''
    }

    def generateEnum(EnumDeclaration ed) {
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

    // enum utils ----------------------------------------------------
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

    // other utils ---------------------------------------------------
    def filename(String filename) {
        imSchema.packagePath.toString + File.separatorChar + filename
    }

}
