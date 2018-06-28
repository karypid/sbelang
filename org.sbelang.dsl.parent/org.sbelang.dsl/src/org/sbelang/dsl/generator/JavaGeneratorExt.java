/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 28 Jun 2018
 */
package org.sbelang.dsl.generator;

/**
 * @author karypid
 *
 */
public interface JavaGeneratorExt
{
    public CharSequence generateEncoderCodeForPrimitiveData(String ownerEncoderClass,
                    String memberVarName, String sbePrimitiveType, int fieldOffset,
                    int fieldOctetLength, int arrayLength, String constLiteral);

    public CharSequence generateDecoderCodeForPrimitiveData(String ownerDecoderClass,
                    String memberVarName, String sbePrimitiveType, int fieldOffset,
                    int fieldOctetLength, int arrayLength, String constLiteral);
}
