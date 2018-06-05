package org.sbelang.dsl.generator;

import java.util.List;

public interface CodecSpec
{
    public String getName();
    public int getTemplateId();
    public int getBlockLength();
    public List<CodecItemSpec> getFields();
    public List<CodecItemSpec> getDataFields();

}
