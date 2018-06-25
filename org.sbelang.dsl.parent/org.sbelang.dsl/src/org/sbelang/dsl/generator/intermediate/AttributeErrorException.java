/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 25 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import org.eclipse.emf.ecore.EObject;

/**
 * @author karypid
 *
 */
public class AttributeErrorException extends Exception
{
    private static final long serialVersionUID = 1L;

    private final EObject grammarElement;

    public AttributeErrorException(String message, EObject grammarElement)
    {
        super(message);
        this.grammarElement = grammarElement;
    }

    public EObject getGrammarElement()
    {
        return grammarElement;
    }
}
