/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import org.sbelang.dsl.sbeLangDsl.BlockDeclaration;

public class ParsedBlock
{
    private final BlockDeclaration blockDeclaration;

    private final ParsedBlock containerMessageOrGroup;

    private final FieldIndex fieldIndex;

    public ParsedBlock(BlockDeclaration compositeType,
                    ParsedBlock containerComposite)
    {
        super();
        this.blockDeclaration = compositeType;
        this.containerMessageOrGroup = containerComposite;
        this.fieldIndex = new FieldIndex(false);
    }

    public BlockDeclaration getBlockDeclaration()
    {
        return blockDeclaration;
    }

    public ParsedBlock getContainerBlock()
    {
        return containerMessageOrGroup;
    }

    public FieldIndex getFieldIndex()
    {
        return fieldIndex;
    }
}
