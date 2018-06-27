/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl

import java.io.File
import java.nio.file.Paths
import org.sbelang.dsl.generator.intermediate.ParsedSchema
import org.sbelang.dsl.generator.intermediate.SbeUtils
import org.sbelang.dsl.sbeLangDsl.CompositeMember
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberRefTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.SetChoiceDeclaration
import org.sbelang.dsl.sbeLangDsl.SetDeclaration
import org.sbelang.dsl.sbeLangDsl.SimpleTypeDeclaration

/**
 * @author karypid
 * 
 */
class JavaEncodersGenerator {
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

    def generateCompositeEncoder(CompositeTypeDeclaration ctd) {
        val compositeName = ctd.name.toFirstUpper + 'Encoder'
        val fieldIndex = parsedSchema.getFieldIndex(ctd.name)
        '''
            package  «parsedSchema.schemaName»;
            
            import org.agrona.MutableDirectBuffer;
            
            public class «compositeName»
            {
                public static final int ENCODED_LENGTH = «fieldIndex.totalOctetLength»;
                
                private int offset;
                private MutableDirectBuffer buffer;
                
                public «compositeName» wrap( final MutableDirectBuffer buffer, final int offset )
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
                            generateComposite_EnumMember_Encoder(ownerComposite, memberType, member.name.toFirstLower)
                        SetDeclaration:
                            generateComposite_SetMember_Encoder(ownerComposite, memberType, member.name.toFirstLower)
                        CompositeTypeDeclaration:
                            generateComposite_CompositeMember_Encoder(ownerComposite, memberType,
                                member.name.toFirstLower)
                        default: ''' /* TODO: reference to non-primitive - «member.toString» : «memberType.name» «memberType.class.name» */'''
                    }
                } else
                    ''' /* TODO: «member.toString» */'''
            }
            // all inline declarations below --------------------
            CompositeTypeDeclaration:
                generateComposite_CompositeMember_Encoder(ownerComposite, member, member.name.toFirstLower)
            EnumDeclaration:
                generateComposite_EnumMember_Encoder(ownerComposite, member, member.name.toFirstLower)
            SetDeclaration:
                generateComposite_SetMember_Encoder(ownerComposite, member, member.name.toFirstLower)
            default: {
                ''' /* NOT IMPLEMENTED YET: «member.toString» */'''
            }
        }
    }

    private def generateComposite_PrimitiveMember_Encoder(String ownerCompositeEncoderClass, String memberVarName,
        String sbePrimitiveType, int fieldOffset, int fieldOctetLength, int arrayLength) {
        val memberValueParamType = JavaGenerator.primitiveToJavaDataType(sbePrimitiveType)
        val memberValueWireType = JavaGenerator.primitiveToJavaWireType(sbePrimitiveType)
        val putSetter = 'put' + memberValueWireType.toFirstUpper
        val optionalEndian = endianParam(memberValueWireType)
        val value = if (memberValueWireType ==
                memberValueParamType) '''value''' else '''(«memberValueWireType») value'''
        val fieldElementLength = SbeUtils.getPrimitiveTypeOctetLength(sbePrimitiveType)

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
                    
                    final int pos = this.offset + «fieldOffset» + (index * «fieldElementLength»);
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
        val memberEnumEncodingJavaType = JavaGenerator.primitiveToJavaWireType(enumMember.encodingType)
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

    private def generateComposite_SetMember_Encoder(CompositeTypeDeclaration ownerComposite, SetDeclaration setMember,
        String memberVarName) {
        val setEncoderClassName = setMember.name.toFirstUpper + 'Encoder'
        val fieldIndex = parsedSchema.getFieldIndex(ownerComposite.name)
        val fieldOffset = fieldIndex.getOffset(setMember.name)

        '''
            // «setMember.name»
            public static int «memberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «memberVarName»EncodingLength()
            {
                return «fieldIndex.getOctectLength(setMember.name)»;
            }
            
            private final «setEncoderClassName» «memberVarName» = new «setEncoderClassName»();
            
            public «setEncoderClassName» «memberVarName»()
            {
                «memberVarName».wrap(buffer, offset + «fieldOffset»);
                return «memberVarName»;
            }
            
        '''
    }

    private def generateComposite_CompositeMember_Encoder(CompositeTypeDeclaration ownerComposite,
        CompositeTypeDeclaration member, String memberVarName) {

        val memberEncoderClass = member.name.toFirstUpper + 'Encoder'
        val fieldIndex = parsedSchema.getFieldIndex(ownerComposite.name)
        val fieldOffset = fieldIndex.getOffset(memberVarName)
        val fieldEncodingLength = fieldIndex.getOctectLength(memberVarName)

        '''
            // «memberEncoderClass»
            public static int «memberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «memberVarName»EncodingLength()
            {
                return «fieldEncodingLength»;
            }
            
            private «memberEncoderClass» «memberVarName» = new «memberEncoderClass»();
            
            public «memberEncoderClass» «memberVarName»()
            {
                «memberVarName».wrap(buffer, offset + «fieldOffset» );
                return «memberVarName»;
            }
            
        '''
    }

    def generateSetEncoder(SetDeclaration sd) {
        val setName = sd.name.toFirstUpper
        val setEncoderName = setName + 'Encoder'
        val setJavaType = JavaGenerator.primitiveToJavaWireType(sd.encodingType)
        val setEncodingOctetLength = SbeUtils.getPrimitiveTypeOctetLength(sd.encodingType)
        val optionalEndian = endianParam(setJavaType)
        val putSetter = 'put' + setJavaType.toFirstUpper

        '''
            package  «parsedSchema.schemaName»;
            
            import org.agrona.MutableDirectBuffer;
            
            public class «setEncoderName»
            {
                public static final int ENCODED_LENGTH = «setEncodingOctetLength»;
                
                private MutableDirectBuffer buffer;
                private int offset;
                
                public «setEncoderName» wrap( final MutableDirectBuffer buffer, final int offset )
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
                
                public «setEncoderName» clear()
                {
                    buffer.«putSetter»( offset, («setJavaType») 0«optionalEndian» );
                    return this;
                }
                
                «FOR setChoice : sd.setChoices»
                    // choice: «setChoice.name»
                    «generateSetChoiceEncoder(sd, setChoice)»
                    
                «ENDFOR»
            }
        '''
    }

    private def generateSetChoiceEncoder(SetDeclaration sd, SetChoiceDeclaration setChoice) {
        val setName = sd.name.toFirstUpper
        val setEncoderName = setName + 'Encoder'
        val setChoiceName = setChoice.name.toFirstLower
        val setJavaType = JavaGenerator.primitiveToJavaWireType(sd.encodingType)
        val constOne = if (setJavaType === 'long') '''1L''' else '''1'''
        val optionalEndian = endianParam(setJavaType)
        val getFetcher = 'get' + setJavaType.toFirstUpper
        val putSetter = 'put' + setJavaType.toFirstUpper
        val bitPos = setChoice.value

        '''
            public «setEncoderName» «setChoiceName»( final boolean value )
            {
                «setJavaType» bits = buffer.«getFetcher»( offset«optionalEndian» );
                bits = («setJavaType») ( value ? bits | («constOne» << «bitPos») : bits & ~(«constOne» << «bitPos») );
                buffer.«putSetter»( offset, bits«optionalEndian» );
                return this;
            }
            
            public static «setJavaType» «setChoiceName»( final short bits, final boolean value )
            {
                return («setJavaType») (value ? bits | («constOne» << «bitPos») : bits & ~(«constOne» << «bitPos») );
            }
        '''
    }

    // java utils ----------------------------------------------------
    private def endianParam(String primitiveJavaType) {
        if (primitiveJavaType == 'byte') '''''' else ''', java.nio.ByteOrder.«parsedSchema.schemaByteOrder»'''
    }

    // other utils ---------------------------------------------------
    def filename(String filename) {
        packagePath.toString + File.separatorChar + filename
    }

}
