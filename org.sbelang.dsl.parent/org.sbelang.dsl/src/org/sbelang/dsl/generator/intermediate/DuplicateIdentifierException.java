/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import org.eclipse.emf.ecore.EObject;

/**
 * @author karypid
 *
 */
public class DuplicateIdentifierException extends Exception
{
    private static final long serialVersionUID = 1L;

    private final EObject element1;
    private final EObject element2;

    public DuplicateIdentifierException(String message, EObject element1, EObject element2)
    {
        super(message);
        this.element1 = element1;
        this.element2 = element2;
    }

    public EObject getElement1()
    {
        return element1;
    }

    public EObject getElement2()
    {
        return element2;
    }
}
