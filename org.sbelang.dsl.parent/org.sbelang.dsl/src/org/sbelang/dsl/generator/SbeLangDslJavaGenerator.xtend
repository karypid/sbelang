package org.sbelang.dsl.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.sbeLangDsl.EnumType
import org.sbelang.dsl.sbeLangDsl.Specification

class SbeLangDslJavaGenerator extends SbeLangDslBaseGenerator {
    
    public static val genJava = Boolean.valueOf(
        System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genJava", "true"))
    public static val genJavaSlice = 
        System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genJavaSlice", null)
    
    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
        if (!genJava) return;
        val spec = resource.getEObject("/") as Specification
        val Parser javaCompiler = new Parser(spec)

        // meta-data for overall message schema
        fsa.generateFile(
            javaCompiler.packagePath + 'MessageSchema.java',
            generateMessageSchema(spec, javaCompiler)
        )
        
        // all enumeration types
        javaCompiler.enumTypes.forEach[name, et | fsa.generateFile(
            javaCompiler.packagePath + name.toFirstUpper + '.java',
            generateEnumType(et, javaCompiler)
        )]
        
        // all composite types
        javaCompiler.compositeTypes.forEach[name, ct | fsa.generateFile(
            javaCompiler.packagePath + name.toFirstUpper + 'Encoder.java',
            generateCodecEncoder(ct, javaCompiler)
        )]

        javaCompiler.messages.forEach[name, msg | fsa.generateFile(
            javaCompiler.packagePath + name.toFirstUpper + 'Encoder.java',
            generateCodecEncoder(msg, javaCompiler)
        )]
    }
    
    def generateEnumType(EnumType et, Parser javaCompiler) {
        '''
            package  «javaCompiler.packageName»;
            
            public enum «et.name.toFirstUpper»
            {
                «FOR v : et.values»
                «v.name»( (short) «v.value» ),
                «ENDFOR»
                ;
                
                private final short value;
                
                «et.name.toFirstUpper»( short value )
                {
                    this.value = value;
                }
                
                public short value()
                {
                    return value;
                }
                
                public static «et.name.toFirstUpper» get(final short value)
                {
                    switch (value)
                    {
                        «FOR v : et.values»
                        case «v.value»: return «v.name»;
                        «ENDFOR»
                    }
            
                    throw new IllegalArgumentException("Unknown value: " + value);
                }
            }
        '''
    }
    
    def generateCodecEncoder(CodecSpec message, Parser javaCompiler) {
        val encoderName = message.name.toFirstUpper + "Encoder";
        '''
            package  «javaCompiler.packageName»;
            
            import java.nio.ByteOrder;
            import org.agrona.MutableDirectBuffer;
            
            public class «encoderName» {
                
                «IF message.templateId != -1»public static final int SCHEMA_ID = «javaCompiler.schemaId»;
                public static final int SCHEMA_VERSION = «javaCompiler.schemaVersion»;
                public static final int TEMPLATE_ID = «message.templateId»;«ENDIF»
                public static final int BLOCK_LENGTH = «message.blockLength»;
                public static final ByteOrder BYTE_ORDER = «javaCompiler.byteOrderConstant»;
                
                private MutableDirectBuffer buffer;
                protected int offset;«IF message.templateId != -1»
                protected int limit;«ENDIF»
                
                public «encoderName» wrap(final MutableDirectBuffer buffer, final int offset)
                {
                    this.buffer = buffer;
                    this.offset = offset;
                    «IF message.templateId != -1»
                    limit(offset + BLOCK_LENGTH);
                    «ENDIF»
                    
                    return this;
                }«IF message.templateId != -1»
                
                public void limit(final int limit)
                {
                    this.limit = limit;
                }«ENDIF»
                «FOR f : message.fields»
                
                int «f.name.toFirstLower»EncodingOffset() {
                    return «f.offset»;
                }
                
                int «f.name.toFirstLower»EncodingLength() {
                    return «f.octetLength»;
                }
                
                «IF f.isPrimitive»
                    «IF f.isConstant»
                    public «f.primitiveJavaType» «f.name.toFirstLower»()
                    {
                        return «f.constantTerminal»;
                    }
                    «ELSE»
                    public «encoderName» «f.name.toFirstLower»(«f.primitiveJavaType» value)
                    {
                        buffer.put«f.primitiveJavaType.toFirstUpper»(offset + «f.offset», («f.primitiveJavaType»)value«IF f.octetLength > 1», BYTE_ORDER«ENDIF»);
                        return this;
                    }
                    «ENDIF»
                «ELSEIF f.isCharArray»
                public «encoderName» put«f.name.toFirstUpper»(final byte[] src, final int srcOffset, final int srcLen)
                {
                    final int length = «f.octetLength»;
                    if (srcOffset < 0 || srcOffset > (src.length - length))
                    {
                        throw new IndexOutOfBoundsException("Copy will go out of range: offset=" + srcOffset);
                    }
                
                    buffer.putBytes(this.offset + 0, src, srcOffset, length);
                
                    return this;
                }
                «IF genJavaSlice !== null»
                
                public «encoderName» put«f.name.toFirstUpper»(final «genJavaSlice» src)
                {
                    final int length = «f.octetLength»;
                    if (src.offset < 0 || src.offset > (src.length - length))
                    {
                        throw new IndexOutOfBoundsException("Copy will go out of range: offset=" + src.offset);
                    }
                
                    buffer.putBytes(this.offset + 0, src.bytes, src.offset, length);
                
                    return this;
                }
                «ENDIF»
                «ELSEIF f.isEnum»
                public «encoderName» «f.name.toFirstLower»(final «f.enumFieldEncodingType.name.toFirstUpper» value)
                {
                    buffer.putByte(offset + 8, (byte)value.value());
                    return this;
                }
                «ENDIF»
                «ENDFOR»
                «FOR f : message.dataFields»
                «ENDFOR»
            }
        '''
    }
    
     // primitive, length == 1 ---> SIMPLE
     // char primitive, length > 1  ---> ARRAY of bytes
     // NON-char primitive, length > 1  ---> weird sbe-tool behavior
     // enum --> spec requires 8-bit char/int only, but says MAY be higher --> sbe-tool weird behaviour at > 1 octet
     // data (1) fixed-length: just X octets with the data's bytes, where X is the fixed length
     // data (2) var-length: uint8/uint16 (1/2 byte) header with length, then that many data octets
     

    def generateMessageSchema(Specification spec, Parser javaCompiler) {
        '''
            package  «javaCompiler.packageName»;
            
            import java.nio.ByteOrder;
            
            public class MessageSchema {
                public static final int SCHEMA_ID = «javaCompiler.schemaId»;
                public static final int SCHEMA_VERSION = «javaCompiler.schemaVersion»;
                public static final ByteOrder BYTE_ORDER = «javaCompiler.byteOrderConstant»;
            }
        '''
    }

}
