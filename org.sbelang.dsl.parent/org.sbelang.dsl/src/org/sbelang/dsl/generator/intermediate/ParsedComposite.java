/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration;

public class ParsedComposite
{
    private final CompositeTypeDeclaration compositeType;

    private final ParsedComposite containerComposite;

    private final FieldIndex fieldIndex;

    public ParsedComposite(CompositeTypeDeclaration compositeType,
                    ParsedComposite containerComposite)
    {
        super();
        this.compositeType = compositeType;
        this.containerComposite = containerComposite;
        this.fieldIndex = new FieldIndex();
    }

    public CompositeTypeDeclaration getCompositeType()
    {
        return compositeType;
    }

    public ParsedComposite getContainerComposite()
    {
        return containerComposite;
    }

    public FieldIndex getFieldIndex()
    {
        return fieldIndex;
    }
}
