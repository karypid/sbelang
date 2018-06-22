/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration;

/**
 * @author karypid
 *
 */
public class CompositeFieldIndex extends FieldIndex
{
    public final CompositeTypeDeclaration ctd;

    public CompositeFieldIndex(CompositeTypeDeclaration ctd)
    {
        this.ctd = ctd;
    }
}
