package org.sbelang.dsl.generator

import java.io.File
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.sbeLangDsl.CompositeType
import org.sbelang.dsl.sbeLangDsl.EncodedDataType
import org.sbelang.dsl.sbeLangDsl.Specification
import org.sbelang.dsl.sbeLangDsl.TypeDeclaration
import java.util.concurrent.atomic.AtomicInteger
import org.sbelang.dsl.sbeLangDsl.Message

class SbeLangDslJavaGenerator extends SbeLangDslBaseGenerator {
    var String packageName
    var String packagePath

    override beforeGenerate(Resource input, IFileSystemAccess2 fsa, IGeneratorContext context) {
        super.beforeGenerate(input, fsa, context)

        val spec = input.getEObject("/") as Specification
        packageName = spec.package.name + ".v" + spec.package.version
        packagePath = packageName.replace('.', File.separatorChar) + File.separatorChar
    }

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
        val spec = resource.getEObject("/") as Specification

        fsa.generateFile(
            packagePath + 'Protocol.java',
            generateProtocol(spec)
        )

        generateTypeDeclarations(fsa, spec.types.types)

        generateMessages(fsa, spec.messages)

    }

    def generateMessages(IFileSystemAccess2 fsa, EList<Message> messages) {
        for (Message message : messages) {
            val encoderName = message.name.toFirstUpper + 'Encoder';
            fsa.generateFile(
                packagePath + encoderName + '.java',
                generateEncoder(encoderName, message.block.fieldsList.fields.filter[f| (f.fieldEncodingType instanceof EncodedDataType) ].map [ f |
                    new Pair(f.name, f.fieldEncodingType)
                ])
            )
        }
    }

    def generateTypeDeclarations(IFileSystemAccess2 fsa, EList<TypeDeclaration> types) {
        for (CompositeType compositeType : types.filter(CompositeType)) {
            generateCompositeType(fsa, compositeType)
        }
    }

    def generateCompositeType(IFileSystemAccess2 fsa, CompositeType compositeTypeDecl) {

        val encoderName = compositeTypeDecl.name.toFirstUpper + 'Encoder';
        fsa.generateFile(
            packagePath + encoderName + '.java',
            generateEncoder(encoderName, compositeTypeDecl.types.types.filter(EncodedDataType)
                .map[edt|new Pair(edt.name, edt)]
            )
        )

        val decoderName = compositeTypeDecl.name.toFirstUpper + 'Decoder';
        fsa.generateFile(
            packagePath + decoderName + '.java',
            '''
                package «packageName»;
                
                public class «decoderName» {
                }
                
            '''
        )
    }

    def generateEncoder(String encoderName, Iterable<Pair<String, EncodedDataType>> fields) {
        '''
            «var AtomicInteger offset = new AtomicInteger(0)»
            package «packageName»;
            
            import org.agrona.MutableDirectBuffer;
            
            public class «encoderName» {
                private int offset;
                private MutableDirectBuffer buffer;
                
                public «encoderName» wrap(final MutableDirectBuffer buffer, final int offset)
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
                «FOR Pair<String,EncodedDataType> pair : fields»
                    «IF !isConstant(pair.value)»
                        public «encoderName» «pair.key.toFirstLower»( final «getJavaType(pair.value)» value) {
                            buffer.put«getWireType(pair.value).toFirstUpper»(offset + «offset.get», («getWireType(pair.value)») value «getByteOrder(pair.value)»);
                            return this;
                        }
                        «offset.set(offset.get + getWireSize(pair.value))»
                    «ENDIF»
                «ENDFOR»
            }
        '''
    }

    def getWireSize(EncodedDataType type) {
        switch (type.primitiveType) {
            case 'char': 2
            case 'float': 4
            case 'double': 8
            case 'int8': 1
            case 'uint8': 1
            case 'int16': 2
            case 'uint16': 2
            case 'int32': 4
            case 'uint32': 4
            case 'int64': 8
            case 'uint64': 8
            default: throw new UnsupportedOperationException("TODO: auto-generated method stub")
        }
    }

    def getByteOrder(EncodedDataType type) {
        if(getWireType(type) == 'byte') '' else ', Protocol.BYTE_ORDER'
    }

    def String getJavaType(EncodedDataType type) {
        switch (type.primitiveType) {
            case 'char': 'char'
            case 'float': 'float'
            case 'double': 'double'
            case 'int8': 'byte'
            case 'uint8': 'short'
            case 'int16': 'short'
            case 'uint16': 'int'
            case 'int32': 'int'
            case 'uint32': 'long'
            case 'int64': 'long'
            case 'uint64': '<UNKNOWN>'
            default: '<UNKNOWN>'
        }
    }

    def String getWireType(EncodedDataType type) {
        switch (type.primitiveType) {
            case 'char': 'char'
            case 'float': 'float'
            case 'double': 'double'
            case 'int8': 'byte'
            case 'uint8': 'byte'
            case 'int16': 'short'
            case 'uint16': 'short'
            case 'int32': 'int'
            case 'uint32': 'int'
            case 'int64': 'long'
            case 'uint64': 'long'
            default: '<UNKNOWN>'
        }
    }

    def generateProtocol(Specification spec) {
        val byteOrder = if((spec.byteOrder === null) ||
                (spec.byteOrder.order == LITTLE_ENDIAN_BYTE_ORDER)) "LITTLE_ENDIAN" else "BIG_ENDIAN";
        val packageName = spec.package.name + ".v" + spec.package.version

        '''
            package  «packageName»;
            
            import java.nio.ByteOrder;
            
            public class Protocol {
                public static final int SCHEMA_ID = «spec.package.id»;
                public static final int SCHEMA_VERSION = «spec.package.version»;
                public static final ByteOrder BYTE_ORDER = ByteOrder.«byteOrder»;
            }
        '''
    }

}