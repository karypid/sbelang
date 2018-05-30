package org.sbelang.dsl.generator;

import org.sbelang.dsl.sbeLangDsl.EncodedDataType;
import org.sbelang.dsl.sbeLangDsl.EnumType;
import org.sbelang.dsl.sbeLangDsl.Field;

public class ParsedMessageField
{
    public final Field f;
    public final int   octetLength;

    public ParsedMessageField(Field f)
    {
        super();
        this.f = f;
        this.octetLength = Parser.getOctetLength(f.getFieldEncodingType());
    }

    public String getName()
    {
        return f.getName();
    }

    public int getOctetLength()
    {
        return octetLength;
    }
    
    public boolean isEnum() {
        return f.getFieldEncodingType() instanceof EnumType;
    }

    public boolean isCharArray()
    {
        if (!(f.getFieldEncodingType() instanceof EncodedDataType)) return false;
        EncodedDataType edt = (EncodedDataType) f.getFieldEncodingType();
        if (!"char".equals(edt.getPrimitiveType())) return false;
        return getOctetLength() > 1;
    }

    public boolean isPrimitive()
    {
        return f.getFieldEncodingType() instanceof EncodedDataType ? getOctetLength() == 1 : false;
    }
}
