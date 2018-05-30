package org.sbelang.dsl.generator;

import java.io.File;
import java.nio.ByteOrder;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

import org.sbelang.dsl.sbeLangDsl.CompositeType;
import org.sbelang.dsl.sbeLangDsl.EncodedDataType;
import org.sbelang.dsl.sbeLangDsl.EnumType;
import org.sbelang.dsl.sbeLangDsl.Specification;
import org.sbelang.dsl.sbeLangDsl.TypeDeclaration;

public class Parser
{
    public static final Map<String, Integer> PRIMITIVE_SIZES;

    static
    {
        Map<String, Integer> map = new LinkedHashMap<String, Integer>();

        map.put("char", 1);
        map.put("int8", 1);
        map.put("int16", 2);
        map.put("int32", 4);
        map.put("int64", 8);
        map.put("uint8", 1);
        map.put("uint16", 2);
        map.put("uint32", 4);
        map.put("uint64", 8);
        map.put("float", 4);
        map.put("double", 8);

        PRIMITIVE_SIZES = Collections.unmodifiableMap(map);
    }

    public final Specification spec;
    public final String        packageName;
    public final String        packagePath;
    public final ByteOrder     byteOrder;

    public final Map<String, EncodedDataType> encodedDataTypes;
    public final Map<String, CompositeType>   compositeTypes;
    public final Map<String, EnumType>        enumTypes;

    public final Map<String, ParsedMessage> messages;

    public Parser(Specification spec)
    {
        this.spec = spec;

        packageName = spec.getPackage().getName() + ".v" + spec.getPackage().getVersion();
        packagePath = packageName.replace('.', File.separatorChar) + File.separatorChar;
        byteOrder = ((spec.getByteOrder() == null) || (spec.getByteOrder()
                        .getOrder() == SbeLangDslBaseGenerator.LITTLE_ENDIAN_BYTE_ORDER))
                                        ? ByteOrder.LITTLE_ENDIAN
                                        : ByteOrder.BIG_ENDIAN;

        encodedDataTypes = spec.getTypesList().getTypes().stream()
                        .filter(t -> t instanceof EncodedDataType).map(t -> (EncodedDataType) t)
                        .collect(Collectors.toMap(t -> t.getName(), t -> t));

        compositeTypes = spec.getTypesList().getTypes().stream()
                        .filter(t -> t instanceof CompositeType).map(t -> (CompositeType) t)
                        .collect(Collectors.toMap(t -> t.getName(), t -> t));

        enumTypes = spec.getTypesList().getTypes().stream().filter(t -> t instanceof EnumType)
                        .map(t -> (EnumType) t).collect(Collectors.toMap(t -> t.getName(), t -> t));

        messages = spec.getMessages().stream()
                        .collect(Collectors.toMap(m -> m.getName(), m -> new ParsedMessage(m)));
    }

    public int getSchemaId()
    {
        return spec.getPackage().getId();
    }

    public int getSchemaVersion()
    {
        return spec.getPackage().getVersion();
    }

    public String getByteOrderConstant()
    {
        return byteOrder == ByteOrder.LITTLE_ENDIAN ? "ByteOrder.LITTLE_ENDIAN"
                        : "ByteOrder.BIG_ENDIAN";
    }

    public static int getOctetLength(TypeDeclaration type)
    {
        if (type instanceof EncodedDataType)
        {
            EncodedDataType edt = (EncodedDataType) type;
            if (edt.getLength() == null) return PRIMITIVE_SIZES.get(edt.getPrimitiveType());
            return edt.getLength().getLength() * PRIMITIVE_SIZES.get(edt.getPrimitiveType());
        }
        else if (type instanceof EnumType)
        {
            EnumType et = (EnumType) type;
            EncodedDataType edt = et.getEnumEncodingType();
            if ((edt.getLength() != null) && (edt.getLength().getLength() != 1))
                throw new IllegalArgumentException(String.format(
                                "illegal encodingType for enum %s length not equal to 1",
                                edt.getName()));
            return PRIMITIVE_SIZES.get(edt.getPrimitiveType());
        }
        return 0;
    }

    // --------------------------------------------------------------------------------

}
