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
import org.sbelang.dsl.sbeLangDsl.SimpleTypeDeclaration

/**
 * @author karypid
 * 
 */
class ToJavaCompiler {
    val ParsedSchema parsedSchema
    val String packagePath

    static val ENUM_NULL_VAL_NAME = "NULL_VAL"

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
            
            public class MessageSchema
            {
                
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
                    «generateComposite_CompositeMember_Encoder(ctd, cm)»
                «ENDFOR»
            }
        '''
    }

    private def generateComposite_CompositeMember_Encoder(CompositeTypeDeclaration ownerComposite,
        CompositeMember member) {
        switch member {
            MemberRefTypeDeclaration: {
                if (member.primitiveType !== null) {
                    val ownerCompositeEncoderClass = ownerComposite.name.toFirstUpper + 'Encoder'
                    val memberVarName = member.name.toFirstLower
                    val fieldIndex = parsedSchema.getFieldIndex(ownerComposite.name)
                    val fieldOffset = fieldIndex.getOffset(member.name)
                    val fieldOctetLength = fieldIndex.getOctectLength(member.name)
                    val arrayLength = if(member.length === null) 1 else member.length
                    generateComposite_PrimitiveMember_Encoder(ownerCompositeEncoderClass, memberVarName,
                        member.primitiveType, fieldOffset, fieldOctetLength, arrayLength)
                } else if (member.type !== null) {
                    val memberType = member.type
                    switch memberType {
                        SimpleTypeDeclaration: {
                            val ownerCompositeEncoderClass = ownerComposite.name.toFirstUpper + 'Encoder'
                            val memberVarName = member.name.toFirstLower
                            val fieldIndex = parsedSchema.getFieldIndex(ownerComposite.name)
                            val fieldOffset = fieldIndex.getOffset(member.name)
                            val fieldOctetLength = fieldIndex.getOctectLength(member.name)
                            val arrayLength = if(memberType.length === null) 1 else memberType.length
                            generateComposite_PrimitiveMember_Encoder(ownerCompositeEncoderClass, memberVarName,
                                memberType.primitiveType, fieldOffset, fieldOctetLength, arrayLength)
                        }
                        EnumDeclaration:
                            generateComposite_EnumMember_Encoder(ownerComposite, memberType, member.name)
                        default: ''' /* TODO: reference to non-primitive - «member.toString» : «memberType.name» «memberType.class.name» */'''
                    }
                } else
                    ''' /* TODO: «member.toString» */'''
            }
            // all inline declarations below --------------------
            CompositeTypeDeclaration:
                generateComposite_CompositeMember_Encoder(ownerComposite, member)
            EnumDeclaration:
                generateComposite_EnumMember_Encoder(ownerComposite, member, member.name.toFirstLower)
            default: {
                ''' /* NOT IMPLEMENTED YET: «member.toString» */'''
            }
        }
    }

    private def generateComposite_PrimitiveMember_Encoder(String ownerCompositeEncoderClass, String memberVarName,
        String sbePrimitiveType, int fieldOffset, int fieldOctetLength, int arrayLength) {
        val memberValueParamType = primitiveToJavaDataType(sbePrimitiveType)
        val memberValueWireType = primitiveToJavaWireType(sbePrimitiveType)
        val putSetter = 'put' + memberValueWireType.toFirstUpper
        val optionalEndian = endianParam(memberValueWireType)
        val value = if (memberValueWireType ==
                memberValueParamType) '''value''' else '''(«memberValueWireType») value'''

        '''
            // «memberVarName»
            public static int «memberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «memberVarName»EncodingLength()
            {
                return «fieldOctetLength»;
            }
            
            «IF arrayLength <= 1»
                public «ownerCompositeEncoderClass» «memberVarName»( final «memberValueParamType» value )
                {
                    buffer.«putSetter»( offset + «fieldOffset», «value» «optionalEndian»);
                    return this;
                }
            «ELSE»
                public static int «memberVarName»Length()
                {
                    return «arrayLength»;
                }
                
                public «ownerCompositeEncoderClass» «memberVarName»( final int index, final «memberValueParamType» value )
                {
                    if (index < 0 || index >= «arrayLength»)
                    {
                        throw new IndexOutOfBoundsException("index out of range: index=" + index);
                    }
                    
                    final int pos = this.offset + «fieldOffset» + (index * 2);
                    buffer.«putSetter»(pos, «value» «optionalEndian»);
                    return this;
                }
                «IF sbePrimitiveType == 'char'»
                
                public «ownerCompositeEncoderClass» put«memberVarName.toFirstUpper»( final byte[] src, final int srcOffset )
                {
                    final int length = «arrayLength»;
                    if (srcOffset < 0 || srcOffset > (src.length - length))
                    {
                        throw new IndexOutOfBoundsException("Copy will go out of range: offset=" + srcOffset);
                    }
                    
                    buffer.putBytes(this.offset + «fieldOffset», src, srcOffset, length);
                    
                    return this;
                }
                «ENDIF»
            «ENDIF»
            
        '''
    }

    private def generateComposite_EnumMember_Encoder(CompositeTypeDeclaration ownerComposite,
        EnumDeclaration enumMember, String memberVarName) {
        val ownerCompositeEncoderClass = ownerComposite.name.toFirstUpper + 'Encoder'
        val fieldIndex = parsedSchema.getFieldIndex(ownerComposite.name)
        val fieldOffset = fieldIndex.getOffset(enumMember.name)

        val memberEnumType = enumMember.name.toFirstUpper
        val memberEnumEncodingJavaType = primitiveToJavaWireType(enumMember.encodingType)
        val putSetter = 'put' + memberEnumEncodingJavaType.toFirstUpper
        val optionalEndian = endianParam(memberEnumEncodingJavaType)

        '''
            // «enumMember.name»
            public static int «memberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «memberVarName»EncodingLength()
            {
                return «fieldIndex.getOctectLength(enumMember.name)»;
            }
            
            public «ownerCompositeEncoderClass» «memberVarName»( final «memberEnumType» value )
            {
                buffer.«putSetter»( offset + «fieldOffset», («memberEnumEncodingJavaType») value.value() «optionalEndian»);
                return this;
            }
            
        '''
    }

    private def generateComposite_CompositeMember_Encoder(CompositeTypeDeclaration ownerComposite,
        CompositeTypeDeclaration member) {

        val memberEncoderClass = member.name.toFirstUpper + 'Encoder'
        val memberVarName = member.name.toFirstLower
        val fieldIndex = parsedSchema.getFieldIndex(ownerComposite.name)
        val fieldOffset = fieldIndex.getOffset(member.name)

        '''
            // «memberEncoderClass»
            public static int «memberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «memberVarName»EncodingLength()
            {
                return «fieldIndex.getOctectLength(member.name)»;
            }
            
            private «memberEncoderClass» «memberVarName» = new «memberEncoderClass»();
            
            public «memberEncoderClass» «memberVarName»()
            {
                «memberVarName».wrap(buffer, offset + «fieldOffset» );
                return «memberVarName»;
            }
            
        '''
    }

    def generateEnumDefinition(EnumDeclaration ed) {
        val enumName = ed.name.toFirstUpper
        val enumValueJavaType = enumJavaType(ed.encodingType)

        // separate null if present and calculate literal
        val enumValuesWithoutNull = ed.enumValues.filter[ev|ev.name != ENUM_NULL_VAL_NAME]
        val explicitNull = ed.enumValues.findFirst[ev|ev.name == ENUM_NULL_VAL_NAME]
        val enumNullValueLiteral = if (isEnumWithExplicitNull(ed.enumValues))
                '''«explicitNull.value»'''
            else
                enumDefaultNullValueLiteral(ed.encodingType)
        '''
            package  «parsedSchema.schemaName»;
            
            public enum «enumName»
            {
                «FOR ev : enumValuesWithoutNull»
                    «ev.name» ( («enumValueJavaType») «ev.value» ),
                «ENDFOR»
                
                «ENUM_NULL_VAL_NAME» ( («enumValueJavaType») «enumNullValueLiteral» );
                
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
                        «FOR ev : enumValuesWithoutNull»
                            case «ev.value»: return «ev.name»;
                        «ENDFOR»
                        case «enumNullValueLiteral»: return «ENUM_NULL_VAL_NAME»;
                        default:
                            throw new IllegalArgumentException ( "Unknown value: " + value );
                    }
                }
            }
        '''
    }

    // java utils ----------------------------------------------------
    private def enumDefaultNullValueLiteral(String enumEncodingType) {
        switch (enumEncodingType) {
            case 'char': '0'
            case 'uint8': '255'
            case 'uint16': '65535'
            default: throw new IllegalStateException("Encoding not supported for enums: " + enumEncodingType)
        }
    }

    private def boolean isEnumWithExplicitNull(EList<EnumValueDeclaration> enumValues) {
        enumValues.exists[evd|evd.name == ENUM_NULL_VAL_NAME]
    }

    private def enumJavaType(String sbePrimitive) {
        switch sbePrimitive {
            case 'char': 'byte'
            case 'uint8': 'short'
            case 'uint16': 'int'
            default: throw new IllegalArgumentException('No enum mapping for: ' + sbePrimitive)
        }
    }

    private def endianParam(String primitiveJavaType) {
        if (primitiveJavaType == 'byte') '''''' else ''', java.nio.ByteOrder.«parsedSchema.schemaByteOrder»'''
    }

    // these are used for encoding. here the unsigned integers are
    // mapped to the signed version as we simply cast when populating
    // buffer values.
    private def primitiveToJavaWireType(String sbePrimitive) {
        switch sbePrimitive {
            case 'char': 'byte' // sbe chars are ascii
            case 'int8': 'byte'
            case 'int16': 'short'
            case 'int32': 'int'
            case 'int64': 'long'
            case 'uint8': 'byte'
            case 'uint16': 'short'
            case 'uint32': 'int'
            case 'uint64': 'long'
            case 'float': 'float'
            case 'double': 'double'
            default: throw new IllegalArgumentException('No enum mapping for: ' + sbePrimitive)
        }
    }

    // these are used in parameters for convenience; here we have wider
    // types for unsigned values where possible (e.g. uint16 is int) to
    // facilitate ease of use, but uint64 naturally remains long as Java
    // has no wider primitive...
    //
    // notably for char we don't widen to java's char as that is a 
    // unicode 16-bit value whereas SBE char is ASCII, therefore we 
    // want to emphasize that...
    private def primitiveToJavaDataType(String sbePrimitive) {
        switch sbePrimitive {
            case 'char': 'byte'
            case 'int8': 'byte'
            case 'int16': 'short'
            case 'int32': 'int'
            case 'int64': 'long'
            case 'uint8': 'short'
            case 'uint16': 'int'
            case 'uint32': 'long'
            case 'uint64': 'long'
            case 'float': 'float'
            case 'double': 'double'
            default: throw new IllegalArgumentException('No enum mapping for: ' + sbePrimitive)
        }
    }

    // other utils ---------------------------------------------------
    def filename(String filename) {
        packagePath.toString + File.separatorChar + filename
    }

}
