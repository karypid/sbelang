package org.sbelang.dsl.generator;

import org.sbelang.dsl.sbeLangDsl.EncodedDataType;
import org.sbelang.dsl.sbeLangDsl.EnumType;
import org.sbelang.dsl.sbeLangDsl.Field;

public class ParsedMessageField implements CodecItemSpec
{
    public final Field f;
    public final int   octetLength;
    public final int   offset;

    public ParsedMessageField(Field f, int offset)
    {
        super();
        this.f = f;
        this.offset = offset;
        this.octetLength = Parser.getOctetLength(f.getFieldEncodingType());
    }

    @Override
    public String getName()
    {
        return f.getName();
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
        return f.getFieldEncodingType() instanceof EnumType;
    }

    @Override
    public EnumType getEnumFieldEncodingType()
    {
        return (EnumType) f.getFieldEncodingType();
    }

    @Override
    public boolean isCharArray()
    {
        if (!(f.getFieldEncodingType() instanceof EncodedDataType)) return false;
        EncodedDataType edt = (EncodedDataType) f.getFieldEncodingType();
        if (!"char".equals(edt.getPrimitiveType())) return false;
        return getOctetLength() > 1;
    }

    @Override
    public boolean isPrimitive()
    {
        return f.getFieldEncodingType() instanceof EncodedDataType ? getOctetLength() == 1 : false;
    }
}
