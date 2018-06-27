package org.sbelang.dsl.generator

import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.JavaDecodersGenerator
import org.sbelang.dsl.JavaEncodersGenertor
import org.sbelang.dsl.generator.intermediate.ParsedSchema

class SbeLangDslJavaGenerator extends SbeLangDslBaseGenerator {

    public static val genJava = Boolean.valueOf(
        System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genJava", "true"))

    override void compile(ParsedSchema schema, IFileSystemAccess2 fsa, IGeneratorContext context) {
        if(!genJava) return;

        val JavaEncodersGenertor encodersGenerator = new JavaEncodersGenertor(schema)
        val JavaDecodersGenerator decodersGenerator = new JavaDecodersGenerator(schema)

        // meta-data for overall message schema
        fsa.generateFile(
            encodersGenerator.filename('MessageSchema.java'),
            encodersGenerator.generateMessageSchema()
        )

        schema.forAllEnums [ ed |
            fsa.generateFile(encodersGenerator.filename(ed.name.toFirstUpper + ".java"),
                encodersGenerator.generateEnumDefinition(ed))
        ]

        schema.forAllSets [ sd |
            fsa.generateFile(encodersGenerator.filename(sd.name.toFirstUpper + "Encoder.java"),
                encodersGenerator.generateSetEncoder(sd))
        ]
        schema.forAllSets [ sd |
            fsa.generateFile(encodersGenerator.filename(sd.name.toFirstUpper + "Decoder.java"),
                decodersGenerator.generateSetDecoder(sd))
        ]

        schema.forAllComposites [ ctd |
            fsa.generateFile(encodersGenerator.filename(ctd.name.toFirstUpper + "Encoder.java"),
                encodersGenerator.generateCompositeEncoder(ctd))
        ]
        schema.forAllComposites [ ctd |
            fsa.generateFile(encodersGenerator.filename(ctd.name.toFirstUpper + "Decoder.java"),
                decodersGenerator.generateCompositeDecoder(ctd))
        ]
    }
}
