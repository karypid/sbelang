package org.sbelang.dsl.generator

import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.generator.JavaDecodersGenerator
import org.sbelang.dsl.generator.JavaEncodersGenerator
import org.sbelang.dsl.generator.JavaGenerator
import org.sbelang.dsl.generator.intermediate.ParsedSchema

class SbeLangDslJavaGenerator extends SbeLangDslBaseGenerator {

    public static val genJava = Boolean.valueOf(
        System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genJava", "true"))

    override void compile(ParsedSchema parsedSchema, IFileSystemAccess2 fsa, IGeneratorContext context) {
        if(!genJava) return;

        val JavaEncodersGenerator encodersGenerator = new JavaEncodersGenerator(parsedSchema)
        val JavaDecodersGenerator decodersGenerator = new JavaDecodersGenerator(parsedSchema)

        // meta-data for overall message schema
        fsa.generateFile(
            encodersGenerator.filename('MessageSchema.java'),
            JavaGenerator.generateMessageSchema(parsedSchema)
        )

        // enumerations each define a Java enum type (common for encoders and decoders)
        parsedSchema.forAllEnums [ ed |
            fsa.generateFile(encodersGenerator.filename(ed.name.toFirstUpper + ".java"),
                JavaGenerator.generateEnumDefinition(parsedSchema, ed))
        ]

        // sets generate encoders and decoders
        parsedSchema.forAllSets [ sd |
            fsa.generateFile(encodersGenerator.filename(sd.name.toFirstUpper + "Encoder.java"),
                encodersGenerator.generateSetEncoder(sd))
        ]
        parsedSchema.forAllSets [ sd |
            fsa.generateFile(encodersGenerator.filename(sd.name.toFirstUpper + "Decoder.java"),
                decodersGenerator.generateSetDecoder(sd))
        ]

        // composites generate encoders and decoders
        parsedSchema.forAllComposites [ ctd |
            fsa.generateFile(encodersGenerator.filename(ctd.name.toFirstUpper + "Encoder.java"),
                encodersGenerator.generateCompositeEncoder(ctd))
        ]
        parsedSchema.forAllComposites [ ctd |
            fsa.generateFile(encodersGenerator.filename(ctd.name.toFirstUpper + "Decoder.java"),
                decodersGenerator.generateCompositeDecoder(ctd))
        ]

        // messages generate encoders and decoders
        parsedSchema.forAllMessages [ bd |
            fsa.generateFile(
                encodersGenerator.filename(bd.name.toFirstUpper + "Encoder.java"),
                encodersGenerator.generateMessageEncoder(bd)
            )
        ]
        parsedSchema.forAllMessages [ bd |
            fsa.generateFile(
                decodersGenerator.filename(bd.name.toFirstUpper + "Decoder.java"),
                decodersGenerator.generateMessageDecoder(bd)
            )
        ]
    }
}
