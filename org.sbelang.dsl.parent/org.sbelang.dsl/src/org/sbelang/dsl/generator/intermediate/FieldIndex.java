/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import org.eclipse.emf.ecore.EObject;

/**
 * Composite type declaration with annotations
 * <p>
 * We add extra information such as a field index and offsets/lengths
 * 
 * @author karypid
 */
public class FieldIndex
{
    private final FieldIndexContainer container;
    private final boolean             caseSensitive;

    private ArrayList<String>  fieldNames;
    private ArrayList<Integer> fieldOffsets;
    private ArrayList<Integer> fieldLengths;
    private ArrayList<EObject> fieldGrammarElements;

    private Map<String, Integer> fieldIndexes;

    private int totalLength;

    public FieldIndex(FieldIndexContainer container, boolean caseSensitive)
    {
        this.container = container;
        this.caseSensitive = caseSensitive;

        fieldNames = new ArrayList<>();
        fieldOffsets = new ArrayList<>();
        fieldLengths = new ArrayList<>();
        fieldGrammarElements = new ArrayList<>();

        fieldIndexes = new HashMap<>();
    }

    public int getTotalLength()
    {
        return totalLength;
    }

    public int addPrimitiveField(String name, String sbePrimitiveType, EObject grammarElement)
                    throws DuplicateIdentifierException
    {
        int offset = totalLength;
        int length = SbeUtils.getPrimitiveTypeOctetLength(sbePrimitiveType);

        int idx = addField(name, offset, length, grammarElement);
        totalLength += length;

        return idx;
    }

    private int addField(String name, int offset, int length, EObject grammarElement)
                    throws DuplicateIdentifierException
    {
        System.out.format("        Adding %s to %s at offset %d with length %d%n", name,
                        container.getContainerName(), offset, length);

        String indexName = caseSensitive ? name : name.toUpperCase();
        int idx = fieldNames.size(); // the next entry in arraylist group...
        Integer existingIdx = fieldIndexes.put(indexName, idx);

        if (existingIdx != null)
        {
            EObject existingGrammarElement = fieldGrammarElements.get(existingIdx);
            String message = String.format(
                            "Duplicate identifier [%s] at %s, collides with existing [%s] at %s.",
                            name, SbeUtils.location(grammarElement), //
                            fieldNames.get(existingIdx), SbeUtils.location(existingGrammarElement));
            throw new DuplicateIdentifierException(message, grammarElement, existingGrammarElement);
        }

        fieldNames.add(name);
        fieldOffsets.add(offset);
        fieldLengths.add(length);
        fieldGrammarElements.add(grammarElement);

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
