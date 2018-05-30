package org.sbelang.dsl.generator;

import java.util.List;
import java.util.stream.Collectors;

import org.sbelang.dsl.sbeLangDsl.Message;

public class ParsedMessage
{
    public final Message m;

    private final List<ParsedMessageField> fields;
    private final List<ParsedMessageField> dataFields;

    public ParsedMessage(Message m)
    {
        super();
        this.m = m;

        fields = m.getBlock().getFieldsList().getFields().stream()
                        .map(f -> new ParsedMessageField(f)).collect(Collectors.toList());
        dataFields = m.getBlock().getDataList().getDataFields().stream()
                        .map(f -> new ParsedMessageField(f)).collect(Collectors.toList());
    }

    public String getName()
    {
        return m.getName();
    }

    public List<ParsedMessageField> getFields()
    {
        return fields;
    }

    public List<ParsedMessageField> getDataFields()
    {
        return dataFields;
    }
}
