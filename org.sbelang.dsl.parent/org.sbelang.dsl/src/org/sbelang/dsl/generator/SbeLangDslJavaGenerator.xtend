package org.sbelang.dsl.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.sbeLangDsl.MessageSchema
import org.sbelang.dsl.generator.intermediate.ImMessageSchema

class SbeLangDslJavaGenerator extends SbeLangDslBaseGenerator {

    public static val genJava = Boolean.valueOf(
        System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genJava", "true"))
    public static val genJavaSlice = System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genJavaSlice",
        null)

    override void compile(ImMessageSchema schema, IFileSystemAccess2 fsa, IGeneratorContext context) {
    }

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
        if(!genJava) return;
        val spec = resource.getEObject("/") as MessageSchema

        // meta-data for overall message schema
        fsa.generateFile(
            '/path/to/' + 'MessageSchema.java',
            generateMessageSchema(spec)
        )
    }

    def generateMessageSchema(MessageSchema spec) {
        '''
            package  «"qualified.package.name"»;
            
            import java.nio.ByteOrder;
            
            public class MessageSchema {
                public static final int SCHEMA_ID = «"0"»;
                public static final int SCHEMA_VERSION = «"0"»;
                public static final ByteOrder BYTE_ORDER = «"null"»;
            }
        '''
    }
}
