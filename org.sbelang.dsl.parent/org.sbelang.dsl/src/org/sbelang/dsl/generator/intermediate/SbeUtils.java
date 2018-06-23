/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

/**
 * @author karypid
 *
 */
public class SbeUtils
{
    public static int getPrimitiveTypeOctetLength(String sbePrimitiveType)
    {
        if ("char".equals(sbePrimitiveType)) return 1;
        else if ("int8".equals(sbePrimitiveType)) return 1;
        else if ("uint8".equals(sbePrimitiveType)) return 1;
        else if ("int16".equals(sbePrimitiveType)) return 2;
        else if ("uint16".equals(sbePrimitiveType)) return 2;
        else if ("int32".equals(sbePrimitiveType)) return 4;
        else if ("uint32".equals(sbePrimitiveType)) return 4;
        else if ("int64".equals(sbePrimitiveType)) return 8;
        else if ("uint64".equals(sbePrimitiveType)) return 8;
        else if ("float".equals(sbePrimitiveType)) return 8;
        else if ("double".equals(sbePrimitiveType)) return 8;
        
        throw new IllegalArgumentException("Unkndown primitive type: [" + sbePrimitiveType + "]");
    }
}
