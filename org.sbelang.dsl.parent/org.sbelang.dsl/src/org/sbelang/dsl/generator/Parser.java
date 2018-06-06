package org.sbelang.dsl.generator;

import java.io.File;
import java.nio.ByteOrder;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

import org.sbelang.dsl.sbeLangDsl.CompositeType;
import org.sbelang.dsl.sbeLangDsl.ConstantModifier;
import org.sbelang.dsl.sbeLangDsl.EncodedDataType;
import org.sbelang.dsl.sbeLangDsl.EnumType;
import org.sbelang.dsl.sbeLangDsl.PresenceModifier;
import org.sbelang.dsl.sbeLangDsl.Specification;
import org.sbelang.dsl.sbeLangDsl.TypeDeclarationOrRef;

public class Parser
{
    public static final Map<String, Integer> PRIMITIVE_SIZES;
    public static final Map<String, String>  PRIMITIVE_JAVA_TYPES;

    static
    {
        Map<String, Integer> primitiveSizesMap = new LinkedHashMap<String, Integer>();
        primitiveSizesMap.put("char", 1);
        primitiveSizesMap.put("int8", 1);
        primitiveSizesMap.put("int16", 2);
        primitiveSizesMap.put("int32", 4);
        primitiveSizesMap.put("int64", 8);
        primitiveSizesMap.put("uint8", 1);
        primitiveSizesMap.put("uint16", 2);
        primitiveSizesMap.put("uint32", 4);
        primitiveSizesMap.put("uint64", 8);
        primitiveSizesMap.put("float", 4);
        primitiveSizesMap.put("double", 8);
        PRIMITIVE_SIZES = Collections.unmodifiableMap(primitiveSizesMap);

        Map<String, String> primitiveTypesMap = new LinkedHashMap<String, String>();
        primitiveTypesMap.put("char", "char");
        primitiveTypesMap.put("int8", "byte");
        primitiveTypesMap.put("int16", "short");
        primitiveTypesMap.put("int32", "int");
        primitiveTypesMap.put("int64", "long");
        primitiveTypesMap.put("uint8", "short");
        primitiveTypesMap.put("uint16", "int");
        primitiveTypesMap.put("uint32", "long");
        // primitiveTypesMap.put("uint64", 8);
        primitiveTypesMap.put("float", "float");
        primitiveTypesMap.put("double", "double");
        PRIMITIVE_JAVA_TYPES = Collections.unmodifiableMap(primitiveTypesMap);
    }

    public final Specification spec;
    public final String        packageName;
    public final String        packagePath;
    public final ByteOrder     byteOrder;

    public final Map<String, EncodedDataType> encodedDataTypes;
    public final Map<String, EnumType>        enumTypes;

    public final Map<String, ParsedCompositeType> compositeTypes;
    public final Map<String, ParsedMessage>       messages;

    public Parser(Specification spec)
    {
        this.spec = spec;

        packageName = spec.getPackage().getName() + ".v" + spec.getPackage().getVersion();
        packagePath = packageName.replace('.', File.separatorChar) + File.separatorChar;
        byteOrder = ((spec.getByteOrder() == null)
                        || (SbeLangDslBaseGenerator.LITTLE_ENDIAN_BYTE_ORDER
                                        .equals(spec.getByteOrder().getOrder())))
                                                        ? ByteOrder.LITTLE_ENDIAN
                                                        : ByteOrder.BIG_ENDIAN;

        encodedDataTypes = spec.getTypesList().getTypes().stream()
                        .filter(t -> t instanceof EncodedDataType).map(t -> (EncodedDataType) t)
                        .collect(Collectors.toMap(t -> t.getName(), t -> t));

        compositeTypes = spec.getTypesList().getTypes().stream()
                        .filter(t -> t instanceof CompositeType).map(t -> (CompositeType) t)
                        .map(t -> new ParsedCompositeType(t))
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

    public static int getOctetLength(TypeDeclarationOrRef type)
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

    public static boolean isConstant(TypeDeclarationOrRef type)
    {
        if (type instanceof EncodedDataType)
        {
            EncodedDataType edt = (EncodedDataType) type;
            if (edt.getPresence() == null) return false;
            if (edt.getPresence() instanceof ConstantModifier) return true;
        }
        return false;
    }

    public static String getPresenceConstant(ConstantModifier cm)
    {
        if (cm.getConstant() != null) return cm.getConstant().trim();
        String s = String.valueOf(cm.getConstantInt());
        return cm.isNegative() ? "-" + s : s;
    }

    // --------------------------------------------------------------------------------

}
