package org.sbelang.dsl.generator;

import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

import org.sbelang.dsl.sbeLangDsl.CompositeType;
import org.sbelang.dsl.sbeLangDsl.TypesList;

public class ParsedCompositeType
{
    public final CompositeType m;

    private final List<CodecItemSpec>          types;
    private final List<ParsedMessageField> dataFields;

    private final int templateId;
    private final int blockLength;

    public ParsedCompositeType(CompositeType m)
    {
        super();
        this.m = m;
        this.templateId = -1;

        TypesList typesList = m.getTypesList();
        int[] offset = new int[1];
        types = typesList == null ? Collections.emptyList() : typesList.getTypes().stream().map(f ->
        {
            int ofs = offset[0];
            offset[0] += Parser.getOctetLength(f);
            return new ParsedCompositeTypeField(f, ofs);
        }).collect(Collectors.toList());

        blockLength = offset[0];

        this.dataFields = Collections.emptyList();
    }

    public String getName()
    {
        return m.getName();
    }

    public List<CodecItemSpec> getFields()
    {
        return types;
    }

    public List<ParsedMessageField> getDataFields()
    {
        return dataFields;
    }

    public int getBlockLength()
    {
        return blockLength;
    }

    public int getTemplateId()
    {
        return templateId;
    }
}
