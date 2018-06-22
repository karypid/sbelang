/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import org.sbelang.dsl.sbeLangDsl.TypeDeclaration;

/**
 * @author karypid
 *
 */
public class DuplicateIdentifierException extends Exception
{
    private static final long serialVersionUID = 1L;

    private final TypeDeclaration element1;
    private final TypeDeclaration element2;

    public DuplicateIdentifierException(String message, TypeDeclaration element1,
                    TypeDeclaration element2)
    {
        super(message);
        this.element1 = element1;
        this.element2 = element2;
    }

    public TypeDeclaration getElement1()
    {
        return element1;
    }

    public TypeDeclaration getElement2()
    {
        return element2;
    }
}
