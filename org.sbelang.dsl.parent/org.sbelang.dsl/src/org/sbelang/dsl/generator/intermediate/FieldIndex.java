/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

/**
 * Composite type declaration with annotations
 * <p>
 * We add extra information such as a field index and offsets/lengths
 * 
 * @author karypid
 */
public class FieldIndex
{
    private ArrayList<String>  fieldNames;
    private ArrayList<Integer> fieldOffsets;
    private ArrayList<Integer> fieldLengths;

    private Map<String, Integer> fieldIndexes;

    private int totalLength;

    public FieldIndex()
    {
        fieldNames = new ArrayList<>();
        fieldOffsets = new ArrayList<>();
        fieldLengths = new ArrayList<>();

        fieldIndexes = new HashMap<>();
    }

    public int getTotalLength()
    {
        return totalLength;
    }

    public int addPrimitiveField(String name, String sbePrimitiveType)
    {
        int offset = totalLength;
        int length = SbeUtils.getPrimitiveTypeOctetLength(sbePrimitiveType);

        int idx = addField(name, offset, length);
        totalLength += length;

        return idx;
    }

    private int addField(String name, int offset, int length)
    {
        fieldNames.add(name);
        fieldOffsets.add(offset);
        fieldLengths.add(length);

        int idx = fieldNames.size() - 1;
        fieldIndexes.put(name, idx);

        return idx;
    }

    public int getOffset(String fieldName)
    {
        Integer idx = fieldIndexes.get(fieldName);
        if (idx == null) return -1;
        // throw new NullPointerException("Could not find field by name: " +
        // fieldName);
        return fieldOffsets.get(idx);
    }

    public int getLength(String fieldName)
    {
        Integer idx = fieldIndexes.get(fieldName);
        if (idx == null) return -1;
        // throw new NullPointerException("Could not find field by name: " +
        // fieldName);
        return fieldLengths.get(idx);
    }
}
