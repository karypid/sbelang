/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.java

import java.io.File
import java.nio.file.Paths
import org.sbelang.dsl.generator.intermediate.FieldIndex
import org.sbelang.dsl.generator.intermediate.ParsedSchema
import org.sbelang.dsl.generator.intermediate.SbeUtils
import org.sbelang.dsl.sbeLangDsl.BlockDeclaration
import org.sbelang.dsl.sbeLangDsl.CompositeMember
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.FieldDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberRefTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.PresenceConstantModifier
import org.sbelang.dsl.sbeLangDsl.SetChoiceDeclaration
import org.sbelang.dsl.sbeLangDsl.SetDeclaration
import org.sbelang.dsl.sbeLangDsl.SimpleTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.GroupDeclaration

/**
 * @author karypid
 * 
 */
class JavaEncodersGenerator {
    val ParsedSchema parsedSchema
    val String packagePath

    val JavaGeneratorExt extensions

    new(ParsedSchema parsedSchema, JavaGeneratorExt extensions) {
        this.parsedSchema = parsedSchema
        this.extensions = extensions

        this.packagePath = {
            val String[] components = parsedSchema.schemaName.split("\\.")
            val schemaPath = Paths.get(".", components)
            Paths.get(".").relativize(schemaPath).normalize.toString
        }
    }

    // -----------------------------------------------------------------------------
    // Code for generating set encoders
    // -----------------------------------------------------------------------------
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

    // -----------------------------------------------------------------------------
    // Code for generating composite encoders
    // -----------------------------------------------------------------------------
    def generateCompositeEncoder(CompositeTypeDeclaration ctd) {
        val encoderClassName = ctd.name.toFirstUpper + 'Encoder'
        val fieldIndex = parsedSchema.getCompositeFieldIndex(ctd.name)

        '''
            package  «parsedSchema.schemaName»;
            
            import org.agrona.MutableDirectBuffer;
            
            public class «encoderClassName»
            {
                public static final int ENCODED_LENGTH = «fieldIndex.totalOctetLength»;
                
                private int offset;
                private MutableDirectBuffer buffer;
                
                public «encoderClassName» wrap( final MutableDirectBuffer buffer, final int offset )
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
                    «generateEncoderCodeForCompositeData(ctd, cm)»
                «ENDFOR»
            }
        '''
    }

    private def generateEncoderCodeForCompositeData(CompositeTypeDeclaration ownerComposite, CompositeMember member) {
        switch member {
            MemberRefTypeDeclaration: {
                val memberVarName = member.name.toFirstLower
                val ownerCompositeEncoderClass = ownerComposite.name.toFirstUpper + 'Encoder'
                val fieldIndex = parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                val fieldOffset = fieldIndex.getOffset(member.name)
                val fieldOctetLength = fieldIndex.getOctectLength(member.name)
                val constLiteral = if (member.presence instanceof PresenceConstantModifier) {
                        (member.presence as PresenceConstantModifier).constantValue
                    } else
                        null

                if (member.primitiveType !== null) {
                    val arrayLength = if(member.length === null) 1 else member.length
                    generateEncoderCodeForPrimitiveData(ownerCompositeEncoderClass, memberVarName,
                        member.primitiveType, fieldOffset, fieldOctetLength, arrayLength, constLiteral)
                } else if (member.type !== null) {
                    val memberType = member.type
                    switch memberType {
                        SimpleTypeDeclaration: {
                            val arrayLength = if(memberType.length === null) 1 else memberType.length
                            generateEncoderCodeForPrimitiveData(ownerCompositeEncoderClass, memberVarName,
                                memberType.primitiveType, fieldOffset, fieldOctetLength, arrayLength, constLiteral)
                        }
                        EnumDeclaration:
                            generateEncoderCodeForEnumerationData(ownerComposite.name, memberType,
                                member.name.toFirstLower, parsedSchema.getCompositeFieldIndex(ownerComposite.name))
                        SetDeclaration:
                            generateEncoderCodeForSetData(
                                memberType,
                                member.name.toFirstLower,
                                parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                            )
                        CompositeTypeDeclaration:
                            generateEncoderCodeForCompositeData(
                                memberType,
                                member.name.toFirstLower,
                                parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                            )
                        default: ''' /* TODO: reference to non-primitive - «member.toString» : «memberType.name» «memberType.class .name» */'''
                    }
                } else
                    ''' /* TODO: «member.toString» */'''
            }
            // all inline declarations below --------------------
            CompositeTypeDeclaration:
                generateEncoderCodeForCompositeData(
                    member,
                    member.name.toFirstLower,
                    parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                )
            EnumDeclaration:
                // val ownerEncoderClassName = ownerComposite.name.toFirstUpper + 'Encoder'
                generateEncoderCodeForEnumerationData(ownerComposite.name, member, member.name.toFirstLower,
                    parsedSchema.getCompositeFieldIndex(ownerComposite.name))
            SetDeclaration:
                generateEncoderCodeForSetData(
                    member,
                    member.name.toFirstLower,
                    parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                )
            default: {
                ''' /* NOT IMPLEMENTED YET: «member.toString» */'''
            }
        }
    }

    // -----------------------------------------------------------------------------
    // Code for generating message encoders
    // -----------------------------------------------------------------------------
    def generateMessageEncoder(BlockDeclaration block) {
        val encoderClassName = block.name.toFirstUpper + 'Encoder'
        val fieldIndex = parsedSchema.getBlockFieldIndex(block.name)

        val classDeclarationInterfaces = if (extensions === null)
                ''''''
            else
                extensions.encoderClassDeclarationExtensions(encoderClassName)

        '''
            package «parsedSchema.schemaName»;
            
            import org.agrona.MutableDirectBuffer;
            
            public class «encoderClassName»«classDeclarationInterfaces»
            {
                public static final int TEMPLATE_ID = «block.id»;
                public static final int BLOCK_LENGTH = «fieldIndex.totalOctetLength»;
                
                private final «encoderClassName» parentMessage = this;
                private MutableDirectBuffer buffer;
                private int offset;
                private int limit;
                
                public int sbeBlockLength()
                {
                    return BLOCK_LENGTH;
                }
                
                public int sbeTemplateId()
                {
                    return TEMPLATE_ID;
                }
                
                public int sbeSchemaId()
                {
                    return MessageSchema.SCHEMA_ID;
                }
                
                public int sbeSchemaVersion()
                {
                    return MessageSchema.SCHEMA_VERSION;
                }
                
                public «encoderClassName» wrap( final MutableDirectBuffer buffer, final int offset )
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
                    return limit - offset;
                }
                
                public int limit()
                {
                    return limit;
                }
                
                public void limit(final int limit)
                {
                    this.limit = limit;
                }
                
                «FOR field : block.fieldDeclarations»
                    «generateEncoderForBlockField(block, field)»
                «ENDFOR»
                
                «FOR group : block.groupDeclarations»
                    // group : «group.block.name»
                    
                    «generateGroupEncoder(encoderClassName, group)»
                «ENDFOR»
            }
        '''
    }

    private def CharSequence generateGroupEncoder(String messageEncoderClassName, GroupDeclaration group) {
        val fieldIndex = parsedSchema.getBlockFieldIndex(group.block.name)
        val memberVarName = group.block.name.toFirstLower
        val groupEncoderClassName = group.block.name.toFirstUpper + 'Encoder'
        val groupSizeDimensionsEncoderClassName = if (group.dimensionType === null)
                '''GroupSizeEncodingEncoder'''
            else
                group.dimensionType.name.toFirstUpper

        val defaultGroupSizeDimensionsDeclarationCode = '''
            private static final int HEADER_SIZE = «groupSizeDimensionsEncoderClassName».ENCODED_LENGTH;
            
            private final «groupSizeDimensionsEncoderClassName» dimensions = new «groupSizeDimensionsEncoderClassName»();
        '''
        val groupSizeDimensionsDeclarations = if (extensions === null)
                defaultGroupSizeDimensionsDeclarationCode
            else
                extensions.groupSizeEncoderDimensionsDeclaration('dimension', defaultGroupSizeDimensionsDeclarationCode);

        val defaultFroupSizeDimensionsPopulationCode = '''
            dimensions.wrap(buffer, parentMessage.limit());
            dimensions.blockLength((int)26);
            dimensions.numInGroup((int)count);
        '''
        val groupSizeDimensionsPopulation = if (extensions === null)
                defaultFroupSizeDimensionsPopulationCode
            else
                extensions.groupSizeEncoderDimensionsPopulation('dimensions', defaultFroupSizeDimensionsPopulationCode)

        '''
            private final «groupEncoderClassName» «memberVarName» = new «groupEncoderClassName»();
            
            public «groupEncoderClassName» «memberVarName»Count( final int count )
            {
                «memberVarName».wrap( parentMessage, buffer, count );
                return «memberVarName»;
            }
            
            public static class «groupEncoderClassName»
            {
                «groupSizeDimensionsDeclarations»
                
                private «messageEncoderClassName» parentMessage;
                private MutableDirectBuffer buffer;
                private int count;
                private int index;
                private int offset;
                
                public void wrap(
                    final «messageEncoderClassName» parentMessage, final MutableDirectBuffer buffer, final int count)
                {
                    if (count < 0 || count > 65534)
                    {
                        throw new IllegalArgumentException("count outside allowed range: count=" + count);
                    }
                    
                    this.parentMessage = parentMessage;
                    this.buffer = buffer;
                    
                    «groupSizeDimensionsPopulation»
                    
                    index = -1;
                    this.count = count;
                    parentMessage.limit(parentMessage.limit() + HEADER_SIZE);
                }
                
                public static int sbeHeaderSize()
                {
                    return HEADER_SIZE;
                }
                
                public static int sbeBlockLength()
                {
                    return «fieldIndex.totalOctetLength»;
                }
                
                public «groupEncoderClassName» next()
                {
                    if (index + 1 >= count)
                    {
                        throw new java.util.NoSuchElementException();
                    }
                    
                    offset = parentMessage.limit();
                    parentMessage.limit( offset + sbeBlockLength() );
                    ++index;
                    
                    return this;
                }
                
                «FOR field : group.block.fieldDeclarations»
                    «generateEncoderForBlockField(group.block, field)»
                «ENDFOR»
                
                «FOR g : group.block.groupDeclarations»
                    // group : «group.block.name»
                    
                    «generateGroupEncoder(messageEncoderClassName, g)»
                «ENDFOR»
            }
            
        '''
    }

    private def generateEncoderForBlockField(BlockDeclaration block, FieldDeclaration field) {
        val fieldIndex = parsedSchema.getBlockFieldIndex(block.name)
        val constLiteral = if (field.presence instanceof PresenceConstantModifier) {
                (field.presence as PresenceConstantModifier).constantValue
            } else
                null

        if (field.primitiveType !== null) {
            return generateEncoderCodeForPrimitiveData(
                block.name.toFirstUpper + "Encoder",
                field.name,
                field.primitiveType,
                fieldIndex.getOffset(field.name),
                fieldIndex.getOctectLength(field.name),
                /* Fixed array length of ONE because fields can't have length */ 1,
                constLiteral
            )
        }

        val type = field.type

        switch type {
            SimpleTypeDeclaration: {
                val arrayLength = if(type.length === null) 1 else type.length
                generateEncoderCodeForPrimitiveData(
                    block.name.toFirstUpper + "Encoder",
                    field.name,
                    type.primitiveType,
                    fieldIndex.getOffset(field.name),
                    fieldIndex.getOctectLength(field.name),
                    arrayLength,
                    constLiteral
                )
            }
            EnumDeclaration:
                generateEncoderCodeForEnumerationData(
                    block.name,
                    type,
                    field.name.toFirstLower,
                    parsedSchema.getBlockFieldIndex(block.name)
                )
            SetDeclaration:
                generateEncoderCodeForSetData(type, field.name.toFirstLower,
                    parsedSchema.getBlockFieldIndex(block.name))
            CompositeTypeDeclaration:
                generateEncoderCodeForCompositeData(type, field.name.toFirstLower,
                    parsedSchema.getBlockFieldIndex(block.name))
            default: '''// TODO: ???? - «field.name» : «type.name»'''
        }
    }

    // -----------------------------------------------------------------------------
    // Common code fragment templates used for both composites and  blocks
    // -----------------------------------------------------------------------------
    private def generateEncoderCodeForPrimitiveData(String ownerCompositeEncoderClass, String memberVarName,
        String sbePrimitiveType, int fieldOffset, int fieldOctetLength, int arrayLength, String constLiteral) {
        val memberValueParamType = JavaGenerator.primitiveToJavaDataType(sbePrimitiveType)
        val memberValueWireType = JavaGenerator.primitiveToJavaWireType(sbePrimitiveType)
        val putSetter = 'put' + memberValueWireType.toFirstUpper
        val optionalEndian = endianParam(memberValueWireType)
        val value = if (memberValueWireType ==
                memberValueParamType) '''value''' else '''(«memberValueWireType») value'''
        val fieldElementLength = SbeUtils.getPrimitiveTypeOctetLength(sbePrimitiveType)

        val constantLiteral = if (constLiteral === null)
                null
            else
                JavaGenerator.javaLiteral(sbePrimitiveType, constLiteral)

        val defaultCode = '''
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
                public «ownerCompositeEncoderClass» «memberVarName»( final «memberValueParamType» value )
                {
                    if ( value != «constantLiteral» )
                        throw new IllegalArgumentException("This is a constant not transmitted on the wire; legal value is only: «constLiteral»");
                    return this;
                }
            «ELSEIF arrayLength <= 1»
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

        if (extensions === null)
            defaultCode
        else {
            extensions.generateEncoderCodeForPrimitiveData(ownerCompositeEncoderClass, memberVarName, sbePrimitiveType,
                fieldOffset, fieldOctetLength, arrayLength, constantLiteral, defaultCode)
        }
    }

    private def generateEncoderCodeForEnumerationData(String ownerName, EnumDeclaration enumMember,
        String memberVarName, FieldIndex fieldIndex) {
        val ownerEncoderClassName = ownerName.toFirstUpper + 'Encoder'
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
            
            public «ownerEncoderClassName» «memberVarName»( final «memberEnumType» value )
            {
                buffer.«putSetter»( offset + «fieldOffset», («memberEnumEncodingJavaType») value.value() «optionalEndian»);
                return this;
            }
            
        '''
    }

    private def generateEncoderCodeForSetData(SetDeclaration setMember, String memberVarName, FieldIndex fieldIndex) {
        val setEncoderClassName = setMember.name.toFirstUpper + 'Encoder'
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

    private def generateEncoderCodeForCompositeData(CompositeTypeDeclaration member, String memberVarName,
        FieldIndex fieldIndex) {

        val memberEncoderClass = member.name.toFirstUpper + 'Encoder'
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
            
            private final «memberEncoderClass» «memberVarName» = new «memberEncoderClass»();
            
            public «memberEncoderClass» «memberVarName»()
            {
                «memberVarName».wrap(buffer, offset + «fieldOffset» );
                return «memberVarName»;
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
