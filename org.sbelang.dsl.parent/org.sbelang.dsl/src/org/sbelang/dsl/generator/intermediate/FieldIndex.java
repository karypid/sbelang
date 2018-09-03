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
    private final boolean caseSensitive;
    private final String  ownerName;

    private ArrayList<String>  fieldNames;
    private ArrayList<Integer> fieldOffsets;
    private ArrayList<Integer> fieldElementLengths;
    private ArrayList<Integer> fieldOctectLengths;
    private ArrayList<EObject> fieldGrammarElements;

    private Map<String, Integer> fieldIndexes;

    private int totalLength;

    public FieldIndex(String ownerName, boolean caseSensitive)
    {
        this.ownerName = ownerName;
        this.caseSensitive = caseSensitive;

        fieldNames = new ArrayList<>();
        fieldOffsets = new ArrayList<>();
        fieldElementLengths = new ArrayList<>();
        fieldOctectLengths = new ArrayList<>();
        fieldGrammarElements = new ArrayList<>();

        fieldIndexes = new HashMap<>();
    }

    public String getOwnerName()
    {
        return ownerName;
    }

    public int getTotalOctetLength()
    {
        return totalLength;
    }

    public int addPrimitiveField(String name, String sbePrimitiveType, int length,
                    EObject grammarElement) throws DuplicateIdentifierException
    {
        int offset = totalLength;
        int octetLength = length == 0 ? -1
                        : SbeUtils.getPrimitiveTypeOctetLength(sbePrimitiveType) * length;

        int idx = addField(name, offset, length, octetLength, grammarElement);
        if (totalLength != -1)
        {
            if (octetLength == -1) totalLength = -1;
            else totalLength += octetLength;
        }

        return idx;
    }

    public int addCompositeField(String name, EObject grammarElement, int length)
                    throws DuplicateIdentifierException
    {
        int offset = totalLength;

        int idx = addField(name, offset, 1, length, grammarElement);
        if (totalLength != -1) totalLength += length;

        return idx;
    }

    private int addField(String name, int offset, int elementsLength, int octetsLength,
                    EObject grammarElement) throws DuplicateIdentifierException
    {
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
        fieldElementLengths.add(elementsLength);
        fieldOctectLengths.add(octetsLength);
        fieldGrammarElements.add(grammarElement);

        if (elementsLength == 0)
        {
            // variable length block/composite...
            totalLength = -1;
        }

        return idx;
    }

    public int getOffset(String fieldName)
    {
        Integer idx = getIndex(fieldName);
        if (idx == null) return -1;
        // throw new NullPointerException("Could not find field by name: " +
        // fieldName);
        return fieldOffsets.get(idx);
    }

    public int getOctectLength(String fieldName)
    {
        Integer idx = getIndex(fieldName);
        if (idx == null) return -1;
        // throw new NullPointerException("Could not find field by name: " +
        // fieldName);
        return fieldOctectLengths.get(idx);
    }

    private Integer getIndex(String fieldName)
    {
        return fieldIndexes.get(fieldName.toUpperCase());
    }
}
