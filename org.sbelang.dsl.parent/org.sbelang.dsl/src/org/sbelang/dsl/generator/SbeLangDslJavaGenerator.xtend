package org.sbelang.dsl.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.sbeLangDsl.Specification
import org.sbelang.dsl.sbeLangDsl.Message
import org.sbelang.dsl.sbeLangDsl.EnumType

class SbeLangDslJavaGenerator extends SbeLangDslBaseGenerator {

    override beforeGenerate(Resource input, IFileSystemAccess2 fsa, IGeneratorContext context) {
        super.beforeGenerate(input, fsa, context)
    }

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
        val spec = resource.getEObject("/") as Specification
        val Parser javaCompiler = new Parser(spec)

        // metadata for overall message schema
        fsa.generateFile(
            javaCompiler.packagePath + 'MessageSchema.java',
            generateMessageSchema(spec, javaCompiler)
        )
        
        javaCompiler.enumTypes.forEach[name, et | fsa.generateFile(
            javaCompiler.packagePath + name.toFirstUpper + '.java',
            generateEnumType(et, javaCompiler)
        )]
        
        javaCompiler.messages.forEach[name, msg|fsa.generateFile(
            javaCompiler.packagePath + name.toFirstUpper + 'Encoder.java',
            generateEncoder(msg, javaCompiler)
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
    
    def generateEncoder(ParsedMessage message, Parser javaCompiler) {
        val encoderName = message.name.toFirstUpper + "Encoder";
        '''
            package  «javaCompiler.packageName»;
            
            import java.nio.ByteOrder;
            import org.agrona.MutableDirectBuffer;
            
            public class «encoderName» {
                
                public static final int SCHEMA_ID = «javaCompiler.schemaId»;
                public static final int SCHEMA_VERSION = «javaCompiler.schemaVersion»;
                public static final int TEMPLATE_ID = «message.templateId»;
                public static final int BLOCK_LENGTH = «message.blockLength»;
                public static final ByteOrder BYTE_ORDER = «javaCompiler.byteOrderConstant»;
                
                private MutableDirectBuffer buffer;
                protected int offset;
                protected int limit;
                
                public «encoderName» wrap(final MutableDirectBuffer buffer, final int offset)
                {
                    this.buffer = buffer;
                    this.offset = offset;
                    limit(offset + BLOCK_LENGTH);
                
                    return this;
                }
                
                public void limit(final int limit)
                {
                    this.limit = limit;
                }
                
                «FOR f : message.fields»
                
                int «f.name»EncodingOffset() {
                    return «f.offset»;
                }
                
                int «f.name»EncodingLength() {
                    return «f.octetLength»;
                }
                
                «IF f.isPrimitive»
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
                «ELSEIF f.isEnum»
                public «encoderName» «f.name.toFirstLower»(final «f.f.fieldEncodingType.name.toFirstUpper» value)
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
