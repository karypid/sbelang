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
import org.sbelang.dsl.sbeLangDsl.PresenceConstantModifier

/**
 * @author karypid
 * 
 */
class JavaDecodersGenerator {
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

    def generateCompositeDecoder(CompositeTypeDeclaration ctd) {
        val compositeName = ctd.name.toFirstUpper + 'Decoder'
        val fieldIndex = parsedSchema.getCompositeFieldIndex(ctd.name)
        '''
            package  «parsedSchema.schemaName»;
            
            import org.agrona.DirectBuffer;
            
            public class «compositeName»
            {
                public static final int ENCODED_LENGTH = «fieldIndex.totalOctetLength»;
                
                private int offset;
                private DirectBuffer buffer;
                
                public «compositeName» wrap( final DirectBuffer buffer, final int offset )
                {
                    this.buffer = buffer;
                    this.offset = offset;
                    
                    return this;
                }
                
                public DirectBuffer buffer()
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
                    «generateComposite_CompositeMember_Decoder(ctd, cm)»
                «ENDFOR»
            }
        '''
    }

    private def generateComposite_CompositeMember_Decoder(CompositeTypeDeclaration ownerComposite,
        CompositeMember member) {
        switch member {
            MemberRefTypeDeclaration: {
                if (member.primitiveType !== null) {
                    val ownerCompositeDecoderClass = ownerComposite.name.toFirstUpper + 'Decoder'
                    val memberVarName = member.name.toFirstLower
                    val fieldIndex = parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                    val fieldOffset = fieldIndex.getOffset(member.name)
                    val fieldOctetLength = fieldIndex.getOctectLength(member.name)
                    val arrayLength = if(member.length === null) 1 else member.length
                    val presence = member.presence
                    val constLiteral = if (presence instanceof PresenceConstantModifier) {
                        presence.constantValue
                    } else null
                    generateComposite_PrimitiveMember_Decoder(ownerCompositeDecoderClass, memberVarName,
                        member.primitiveType, fieldOffset, fieldOctetLength, arrayLength, constLiteral)
                } else if (member.type !== null) {
                    val memberType = member.type
                    switch memberType {
                        SimpleTypeDeclaration: {
                            val ownerCompositeDecoderClass = ownerComposite.name.toFirstUpper + 'Decoder'
                            val memberVarName = member.name.toFirstLower
                            val fieldIndex = parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                            val fieldOffset = fieldIndex.getOffset(member.name)
                            val fieldOctetLength = fieldIndex.getOctectLength(member.name)
                            val arrayLength = if(memberType.length === null) 1 else memberType.length
                            val presence = member.presence
                            val constLiteral = if (presence instanceof PresenceConstantModifier) {
                                presence.constantValue
                            } else null
                            generateComposite_PrimitiveMember_Decoder(ownerCompositeDecoderClass, memberVarName,
                                memberType.primitiveType, fieldOffset, fieldOctetLength, arrayLength, constLiteral)
                        }
                        EnumDeclaration:
                            generateComposite_EnumMember_Decoder(ownerComposite, memberType, member.name.toFirstLower)
                        SetDeclaration:
                            generateComposite_SetMember_Decoder(ownerComposite, memberType, member.name.toFirstLower)
                        CompositeTypeDeclaration:
                            generateComposite_CompositeMember_Decoder(ownerComposite, memberType, member.name.toFirstLower)
                        default: ''' /* TODO: reference to non-primitive - «member.toString» : «memberType.name» «memberType.class.name» */'''
                    }
                } else
                    ''' /* TODO: «member.toString» */'''
            }
            // all inline declarations below --------------------
            CompositeTypeDeclaration:
                generateComposite_CompositeMember_Decoder(ownerComposite, member, member.name.toFirstLower)
            EnumDeclaration:
                generateComposite_EnumMember_Decoder(ownerComposite, member, member.name.toFirstLower)
            SetDeclaration:
                generateComposite_SetMember_Decoder(ownerComposite, member, member.name.toFirstLower)
            default: {
                ''' /* NOT IMPLEMENTED YET: «member.toString» */'''
            }
        }
    }

    private def generateComposite_PrimitiveMember_Decoder(String ownerCompositeEncoderClass, String memberVarName,
        String sbePrimitiveType, int fieldOffset, int fieldOctetLength, int arrayLength, String constantLiteral) {
        val memberValueParamType = JavaGenerator.primitiveToJavaDataType(sbePrimitiveType)
        val memberValueWireType = JavaGenerator.primitiveToJavaWireType(sbePrimitiveType)
        val getFetcher = 'get' + memberValueWireType.toFirstUpper
        val optionalEndian = endianParam(memberValueWireType)
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
            
            «IF constantLiteral !== null»
                public «memberValueParamType» «memberVarName»()
                {
                    return «constantLiteral»;
                }
            «ELSEIF arrayLength <= 1»
                public «memberValueParamType» «memberVarName»()
                {
                    return buffer.«getFetcher»( offset + «fieldOffset» «optionalEndian»);
                }
            «ELSE»
                public static int «memberVarName»Length()
                {
                    return «arrayLength»;
                }
                
                public «memberValueParamType» «memberVarName»( final int index )
                {
                    if (index < 0 || index >= «arrayLength»)
                    {
                        throw new IndexOutOfBoundsException("index out of range: index=" + index);
                    }
                    
                    final int pos = this.offset + «fieldOffset» + (index * «fieldElementLength»);
                    return buffer.«getFetcher»(pos «optionalEndian»);
                }
                «IF sbePrimitiveType == 'char'»
                
                public int get«memberVarName.toFirstUpper»( final byte[] dst, final int dstOffset )
                {
                    final int length = «arrayLength»;
                    if (dstOffset < 0 || dstOffset > (dst.length - length))
                    {
                        throw new IndexOutOfBoundsException("Copy will go out of range: offset=" + dstOffset);
                    }
                    
                    buffer.getBytes(this.offset + «fieldOffset», dst, dstOffset, length);
                    
                    return length;
                }
                «ENDIF»
            «ENDIF»
            
        '''
    }

    private def generateComposite_EnumMember_Decoder(CompositeTypeDeclaration ownerComposite,
        EnumDeclaration enumMember, String memberVarName) {
        val fieldIndex = parsedSchema.getCompositeFieldIndex(ownerComposite.name)
        val fieldOffset = fieldIndex.getOffset(enumMember.name)

        val memberEnumType = enumMember.name.toFirstUpper
        val memberEnumJavaWireType = JavaGenerator.primitiveToJavaWireType(enumMember.encodingType)
        val memberEnumJavaDataType = JavaGenerator.primitiveToJavaDataType(enumMember.encodingType)
        val getFetcher = 'get' + memberEnumJavaWireType.toFirstUpper
        val optionalEndian = endianParam(memberEnumJavaWireType)
        
        val mask = enumAllBitsMask(enumMember.encodingType)
        val maskStart = if (mask=='') '''''' else '''('''
        val maskEnd = if (mask=='') '''''' else ''' & «mask»)'''

        val cast = if (memberEnumJavaWireType !== memberEnumJavaDataType) '''(«memberEnumJavaDataType»)'''

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
            
            public «memberEnumType» «memberVarName»()
            {
                return «memberEnumType».get( «cast» «maskStart»buffer.«getFetcher»( offset + «fieldOffset»«optionalEndian»)«maskEnd» );
            }
            
        '''
    }
    
    private def generateComposite_SetMember_Decoder(CompositeTypeDeclaration ownerComposite,
        SetDeclaration setMember, String memberVarName) {
        val setDecoderClassName = setMember.name.toFirstUpper + 'Decoder'
        val fieldIndex = parsedSchema.getCompositeFieldIndex(ownerComposite.name)
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
            
            private final «setDecoderClassName» «memberVarName» = new «setDecoderClassName»();
            
            public «setDecoderClassName» «memberVarName»()
            {
                «memberVarName».wrap(buffer, offset + «fieldOffset»);
                return «memberVarName»;
            }
            
        '''
    }

    private def generateComposite_CompositeMember_Decoder(CompositeTypeDeclaration ownerComposite,
        CompositeTypeDeclaration member, String memberVarName) {

        val memberDecoderClass = member.name.toFirstUpper + 'Decoder'
        val fieldIndex = parsedSchema.getCompositeFieldIndex(ownerComposite.name)
        val fieldOffset = fieldIndex.getOffset(memberVarName)
        val fieldEncodingLength = fieldIndex.getOctectLength(memberVarName)

        '''
            // «memberDecoderClass»
            public static int «memberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «memberVarName»EncodingLength()
            {
                return «fieldEncodingLength»;
            }
            
            private «memberDecoderClass» «memberVarName» = new «memberDecoderClass»();
            
            public «memberDecoderClass» «memberVarName»()
            {
                «memberVarName».wrap(buffer, offset + «fieldOffset» );
                return «memberVarName»;
            }
            
        '''
    }

    def generateSetDecoder(SetDeclaration sd) {
        val setName = sd.name.toFirstUpper
        val setDecoderName = setName + 'Decoder'
        val setEncodingOctetLength = SbeUtils.getPrimitiveTypeOctetLength(sd.encodingType)
        
        '''
            package  «parsedSchema.schemaName»;
            
            import org.agrona.DirectBuffer;
            
            public class «setDecoderName»
            {
                public static final int ENCODED_LENGTH = «setEncodingOctetLength»;
                
                private DirectBuffer buffer;
                private int offset;
                
                public «setDecoderName» wrap( final DirectBuffer buffer, final int offset )
                {
                    this.buffer = buffer;
                    this.offset = offset;
                
                    return this;
                }
                
                public DirectBuffer buffer()
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
                
                «FOR setChoice : sd.setChoices»
                    // choice: «setChoice.name»
                    «generateSetChoiceDecoder(sd, setChoice)»
                    
                «ENDFOR»
            }
        '''
    }
    
    private def generateSetChoiceDecoder(SetDeclaration sd, SetChoiceDeclaration setChoice) {
        val setChoiceName = setChoice.name.toFirstLower
        val setJavaType = JavaGenerator.primitiveToJavaWireType(sd.encodingType)
        val getFetcher = 'get' + setJavaType.toFirstUpper
        val optionalEndian = endianParam(setJavaType)
        val constOne = if (setJavaType === 'long') '''1L''' else '''1'''
        val bitPos = setChoice.value
        
        '''
            public boolean «setChoiceName»()
            {
                return 0 !=  ( buffer.«getFetcher»( offset«optionalEndian» ) & («constOne» << «bitPos») );
            }
            
            public static boolean «setChoiceName»( final «setJavaType» value )
            {
                return 0 !=  ( value & («constOne» << «bitPos») );
            }
        '''
    }

    // java utils ----------------------------------------------------
    private def endianParam(String primitiveJavaType) {
        if (primitiveJavaType == 'byte') '''''' else ''', java.nio.ByteOrder.«parsedSchema.schemaByteOrder»'''
    }

    private def enumAllBitsMask(String sbeEnumEncodingType) {
        switch (sbeEnumEncodingType) {
            case 'char' : ''
            case 'uint8' : '0xFF'
            case 'uint16' : '0xFFFF'
            default: throw new IllegalStateException('Why would you need this? Enums should not be of type: ' + sbeEnumEncodingType)
        }
    }

    // other utils ---------------------------------------------------
    def filename(String filename) {
        packagePath.toString + File.separatorChar + filename
    }

}