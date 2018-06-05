package org.sbelang.dsl.generator;

import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

import org.sbelang.dsl.sbeLangDsl.DataList;
import org.sbelang.dsl.sbeLangDsl.FieldsList;
import org.sbelang.dsl.sbeLangDsl.Message;

public class ParsedMessage implements CodecSpec
{
    public final Message m;

    private final List<CodecItemSpec> fields;
    private final List<CodecItemSpec> dataFields;

    private final int blockLength;

    public ParsedMessage(Message m)
    {
        super();
        this.m = m;

        FieldsList fieldsList = m.getBlock().getFieldsList();
        int[] offset = new int[1];
        fields = fieldsList == null ? Collections.emptyList()
                        : fieldsList.getFields().stream().map(f ->
                        {
                            int ofs = offset[0];
                            offset[0] += Parser.getOctetLength(f.getFieldEncodingType());
                            return new ParsedMessageField(f, ofs);
                        }).collect(Collectors.toList());

        DataList dataList = m.getBlock().getDataList();
        dataFields = dataList == null ? Collections.emptyList()
                        : dataList.getDataFields().stream().map(f -> new ParsedMessageField(f, -1))
                                        .collect(Collectors.toList());

        blockLength = fields.stream().mapToInt(f -> f.getOctetLength()).sum();
    }

    @Override
    public String getName()
    {
        return m.getName();
    }

    @Override
    public int getTemplateId()
    {
        return m.getId();
    }

    @Override
    public int getBlockLength()
    {
        return blockLength;
    }

    @Override
    public List<CodecItemSpec> getFields()
    {
        return fields;
    }

    @Override
    public List<CodecItemSpec> getDataFields()
    {
        return dataFields;
    }
}
