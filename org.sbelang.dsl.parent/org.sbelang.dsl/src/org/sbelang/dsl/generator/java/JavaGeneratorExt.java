/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 28 Jun 2018
 */
package org.sbelang.dsl.generator.java;

/**
 * @author karypid
 *
 */
public interface JavaGeneratorExt
{
    // encoder extensions

    public CharSequence encoderClassDeclarationExtensions(String encoderClassName);

    public CharSequence generateEncoderCodeForPrimitiveData(String encoderClassName,
                    String memberVarName, String sbePrimitiveType, int fieldOffset,
                    int fieldOctetLength, int arrayLength, String constLiteral,
                    CharSequence defaultGeneratedCode);

    // decoder extensions

    public CharSequence decoderClassDeclarationExtensions(String decoderClassName);

    public CharSequence generateDecoderCodeForPrimitiveData(String decoderClassName,
                    String memberVarName, String sbePrimitiveType, int fieldOffset,
                    int fieldOctetLength, int arrayLength, String constLiteral,
                    CharSequence defaultGeneratedCode);
}
