package org.sbelang.dsl.generator;

import org.sbelang.dsl.sbeLangDsl.ConstantModifier;
import org.sbelang.dsl.sbeLangDsl.EncodedDataType;
import org.sbelang.dsl.sbeLangDsl.EnumType;
import org.sbelang.dsl.sbeLangDsl.TypeDeclarationOrRef;

public class ParsedCompositeTypeField implements CodecItemSpec
{
    public final TypeDeclarationOrRef type;
    public final int                  octetLength;
    public final int                  offset;

    public ParsedCompositeTypeField(TypeDeclarationOrRef type, int offset)
    {
        super();
        this.type = type;
        this.offset = offset;
        this.octetLength = Parser.getOctetLength(type);
    }

    @Override
    public String getName()
    {
        return type.getName();
    }

    @Override
    public int getOffset()
    {
        return offset;
    }

    @Override
    public int getOctetLength()
    {
        return octetLength;
    }

    @Override
    public boolean isEnum()
    {
        return false;
    }

    @Override
    public boolean isCharArray()
    {
        return false;
    }

    @Override
    public boolean isPrimitive()
    {
        return type instanceof EncodedDataType ? getOctetLength() == 1 : false;
    }

    @Override
    public EnumType getEnumFieldEncodingType()
    {
        return null;
    }

    @Override
    public String getPrimitiveJavaType()
    {
        return Parser.PRIMITIVE_JAVA_TYPES.get(((EncodedDataType) type).getPrimitiveType());
    }

    @Override
    public boolean isConstant()
    {
        return Parser.isConstant(type);
    }
    
    @Override
    public String getConstantTerminal()
    {
        return Parser.getPresenceConstant((ConstantModifier) ((EncodedDataType) type).getPresence());
    }
}
