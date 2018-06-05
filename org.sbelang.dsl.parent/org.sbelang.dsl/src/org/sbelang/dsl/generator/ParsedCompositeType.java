package org.sbelang.dsl.generator;

import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

import org.sbelang.dsl.sbeLangDsl.CompositeType;
import org.sbelang.dsl.sbeLangDsl.TypesList;

public class ParsedCompositeType implements CodecSpec
{
    public final CompositeType m;

    private final List<CodecItemSpec>          types;
    private final List<CodecItemSpec> dataFields;

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

    @Override
    public String getName()
    {
        return m.getName();
    }

    @Override
    public int getTemplateId()
    {
        return templateId;
    }

    @Override
    public int getBlockLength()
    {
        return blockLength;
    }

    @Override
    public List<CodecItemSpec> getFields()
    {
        return types;
    }

    @Override
    public List<CodecItemSpec> getDataFields()
    {
        return dataFields;
    }
}
