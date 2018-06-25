/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.xtext.nodemodel.ICompositeNode;
import org.eclipse.xtext.nodemodel.util.NodeModelUtils;

/**
 * @author karypid
 *
 */
public class SbeUtils
{
    public static final List<String> PRIMITIVE_TYPES = Collections
                    .unmodifiableList(Arrays.asList("char", "int8", "int16", "int32", "int64",
                                    "uint8", "uint16", "uint32", "uint64", "float", "double"));

    public static String location(ICompositeNode node)
    {
        int s = node.getStartLine();
        int e = node.getEndLine();
        return s == e ? ("line " + s) : String.format("lines %d-%d", s, e);
    }

    public static String location(EObject grammarElement)
    {
        ICompositeNode node = NodeModelUtils.getNode(grammarElement);
        return location(node);
    }

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
        else if ("float".equals(sbePrimitiveType)) return 4;
        else if ("double".equals(sbePrimitiveType)) return 8;

        throw new IllegalArgumentException("Unkndown primitive type: [" + sbePrimitiveType + "]");
    }
}
