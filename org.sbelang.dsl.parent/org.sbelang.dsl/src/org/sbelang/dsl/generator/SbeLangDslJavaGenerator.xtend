package org.sbelang.dsl.generator

import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.ToJavaCompiler
import org.sbelang.dsl.generator.intermediate.ImMessageSchema
import org.sbelang.dsl.generator.intermediate.ParsedSchema

class SbeLangDslJavaGenerator extends SbeLangDslBaseGenerator {

    public static val genJava = Boolean.valueOf(
        System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genJava", "true"))

    override void compile(ParsedSchema schema, IFileSystemAccess2 fsa, IGeneratorContext context) {
        
    }

    override void compile(ImMessageSchema imSchema, IFileSystemAccess2 fsa, IGeneratorContext context) {
        if(!genJava) return;

        val ToJavaCompiler compiler = new ToJavaCompiler(imSchema)

        // meta-data for overall message schema
        fsa.generateFile(
            compiler.filename('MessageSchema.java'),
            compiler.generateMessageSchema()
        )

        imSchema.fqnEnumsMap.forEach [ enumName, ed |
            fsa.generateFile(compiler.filename(ed.name.toFirstUpper + ".java"), compiler.generateEnum(ed))
        ]

        imSchema.fqnCompositesMap.forEach [ compositeName, ctd |
            fsa.generateFile(compiler.filename(ctd.name.toFirstUpper + "Encoder.java"),
                compiler.generateCompositeEncoder(ctd))
        ]
    }
}
