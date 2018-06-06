package org.sbelang.dsl.generator;

import org.sbelang.dsl.sbeLangDsl.EnumType;

public interface CodecItemSpec
{

    String getName();

    int getOffset();

    int getOctetLength();

    boolean isEnum();

    boolean isCharArray();

    boolean isPrimitive();
    
    boolean isConstant();

    EnumType getEnumFieldEncodingType();
    
    String getPrimitiveJavaType();

    String getConstantTerminal();

}
