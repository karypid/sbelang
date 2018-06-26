/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl

import java.io.File
import java.nio.ByteOrder
import java.nio.file.Paths
import org.eclipse.emf.common.util.EList
import org.sbelang.dsl.generator.intermediate.ParsedSchema
import org.sbelang.dsl.sbeLangDsl.CompositeMember
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumValueDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberRefTypeDeclaration

/**
 * @author karypid
 * 
 */
class ToJavaCompiler {
    val ParsedSchema parsedSchema
    val String packagePath

    new(ParsedSchema parsedSchema) {
        this.parsedSchema = parsedSchema

        this.packagePath = {
            val String[] components = parsedSchema.schemaName.split("\\.")
            val schemaPath = Paths.get(".", components)
            Paths.get(".").relativize(schemaPath).normalize.toString
        }
    }

    def generateMessageSchema() {
        val schemaByteOrderConstant = if(parsedSchema.schemaByteOrder ===
                ByteOrder.BIG_ENDIAN) "BIG_ENDIAN" else "LITTLE_ENDIAN"
        '''
            package  «parsedSchema.schemaName»;
            
            import java.nio.ByteOrder;
            
            public class MessageSchema {
                public static final int SCHEMA_ID = «parsedSchema.schemaId»;
                public static final int SCHEMA_VERSION = «parsedSchema.schemaVersion»;
                public static final ByteOrder BYTE_ORDER = ByteOrder.«schemaByteOrderConstant»;
            }
        '''
    }

    def generateCompositeEncoder(CompositeTypeDeclaration ctd) {
        val compositeName = ctd.name.toFirstUpper + 'Encoder'
        '''
            package  «parsedSchema.schemaName»;
            
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
            MemberRefTypeDeclaration: {
                if (member.primitiveType !== null)
                    generatePrimitiveEncoderMember(ownerComposite, member)
                else if (member.type !== null)
                    ''' /* TODO: reference to non-primitive - «member.toString» */'''
                else
                    ''' /* TODO: «member.toString» */'''
            }
            default: {
                ''' /* NOT IMPLEMENTED YET: «member.toString» */'''
            }
        }
    }

    private def generatePrimitiveEncoderMember(CompositeTypeDeclaration ownerComposite,
        MemberRefTypeDeclaration member) {
        val ownerCompositeEncoderClass = ownerComposite.name.toFirstUpper + 'Encoder'
        val meberVarName = member.name.toFirstLower
        val fieldIndex = parsedSchema.getFieldIndex(ownerComposite.name)
        val fieldOffset = fieldIndex.getOffset(member.name)
        val memberValueJavaType = primitiveToJavaType(member.primitiveType)

        '''
            // «meberVarName»
            public static int «meberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «meberVarName»EncodingLength()
            {
                return «fieldIndex.getLength(member.name)»;
            }
            
            public «ownerCompositeEncoderClass» «meberVarName»( «memberValueJavaType» value )
            {
                buffer.put«memberValueJavaType.toFirstUpper»(offset + «fieldOffset», value);
                return this;
            }
            
        '''
    }

    private def generateCompositeEncoderMember(CompositeTypeDeclaration ownerComposite,
        CompositeTypeDeclaration member) {

        val memberEncoderClass = member.name.toFirstUpper + 'Encoder'
        val meberVarName = member.name.toFirstLower
        val fieldIndex = parsedSchema.getFieldIndex(ownerComposite.name)
        val fieldOffset = fieldIndex.getOffset(member.name)

        '''
            // «memberEncoderClass»
            public static int «meberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «meberVarName»EncodingLength()
            {
                return «fieldIndex.getLength(member.name)»;
            }
            
            private «memberEncoderClass» «meberVarName» = new «memberEncoderClass»();
            
            public «memberEncoderClass» «meberVarName»()
            {
                «meberVarName».wrap(buffer, offset + «fieldOffset» );
                return «meberVarName»;
            }
            
        '''
    }

    def generateEnum(EnumDeclaration ed) {
        val enumName = ed.name.toFirstUpper
        val enumValueJavaType = enumJavaType(ed.encodingType)
        val enumNullValueLiteral = enumDefaultNullValueLiteral(ed.encodingType)
        '''
            package  «parsedSchema.schemaName»;
            
            public enum «enumName»
            {
                «FOR ev : ed.enumValues»
                    «ev.name» ( («enumValueJavaType») «ev.value» ),
                «ENDFOR»«IF !isEnumWithExplicitNull(ed.enumValues)»
                    
                NULL_VAL ( («enumValueJavaType») «enumNullValueLiteral» )«ENDIF»;
                
                public final «enumValueJavaType» value;
                
                private «enumName»( final «enumValueJavaType» value )
                {
                    this.value = value;
                }
                
                public «enumValueJavaType» value()
                {
                    return value;
                }
                
                public static «enumName» get ( final «enumValueJavaType» value )
                {
                    switch ( value )
                    {
                        «FOR ev : ed.enumValues»
                            case «ev.value»: return «ev.name»;
                        «ENDFOR»
                        case «enumNullValueLiteral»: return NULL_VAL;
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
    
    private def primitiveToJavaType(String sbePrimitive) {
        switch sbePrimitive {
            case 'char': 'char'
            case 'int8': 'byte'
            case 'int16': 'short'
            case 'int32': 'int'
            case 'int64': 'long'
            case 'uint8': 'byte'
            case 'uint16': 'short'
            case 'uint32': 'int'
            case 'uint64': 'long'
            case 'float': 'float'
            case 'double': 'float'
            default: throw new IllegalArgumentException('No enum mapping for: ' + sbePrimitive)
        }
    }

    // other utils ---------------------------------------------------
    def filename(String filename) {
        packagePath.toString + File.separatorChar + filename
    }

}
