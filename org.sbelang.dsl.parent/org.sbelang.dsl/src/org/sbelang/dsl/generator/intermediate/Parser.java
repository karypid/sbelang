/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.intermediate;

import java.util.LinkedHashMap;
import java.util.Map;

import org.eclipse.xtext.nodemodel.ICompositeNode;
import org.eclipse.xtext.nodemodel.util.NodeModelUtils;
import org.sbelang.dsl.sbeLangDsl.CompositeMember;
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration;
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration;
import org.sbelang.dsl.sbeLangDsl.MemberPrimitiveTypeDeclaration;
import org.sbelang.dsl.sbeLangDsl.MemberRefTypeDeclaration;
import org.sbelang.dsl.sbeLangDsl.MessageSchema;
import org.sbelang.dsl.sbeLangDsl.SetDeclaration;
import org.sbelang.dsl.sbeLangDsl.SimpleTypeDeclaration;
import org.sbelang.dsl.sbeLangDsl.TypeDeclaration;

public class Parser
{
    public static ParsedSchema parse(MessageSchema schema) throws Exception
    {
        Parser parser = new Parser(schema);
        return parser.parse();
    }

    private final MessageSchema schema;

    // index all root objects by name
    private final Map<String, SimpleTypeDeclaration>    rootSimpleTypes;
    private final Map<String, EnumDeclaration>          rootEnumerations;
    private final Map<String, SetDeclaration>           rootSets;
    private final Map<String, CompositeTypeDeclaration> rootComposites;

    // all root names must be unique in a case-insensitive manner as they may be
    // referenced in composites; furthermore, nested container types
    // (enum/set/composite) must also have globally unique names, as they may
    // cause
    private final Map<String, TypeDeclaration> allRootNames;

    private Parser(MessageSchema schema)
    {
        super();

        this.schema = schema;

        this.rootSimpleTypes = new LinkedHashMap<>();
        this.rootEnumerations = new LinkedHashMap<>();
        this.rootSets = new LinkedHashMap<>();
        this.rootComposites = new LinkedHashMap<>();

        this.allRootNames = new LinkedHashMap<>();
    }

    private String location(ICompositeNode node)
    {
        int s = node.getStartLine();
        int e = node.getEndLine();
        return s == e ? ("line " + s) : String.format("lines %d-%d", s, e);
    }

    private void checkUnique(TypeDeclaration td) throws DuplicateIdentifierException
    {
        String caseInsensitiveName = td.getName().toUpperCase();

        TypeDeclaration existing = allRootNames.put(caseInsensitiveName, td);

        if (existing != null)
        {
            ICompositeNode collidingNode = NodeModelUtils.getNode(td);
            ICompositeNode existingNode = NodeModelUtils.getNode(existing);

            String message = String.format(
                            "At %s name [%s] collides with previously defined [%s] at %s (note: case-insensitive)",
                            location(collidingNode), td.getName(), existing.getName(),
                            location(existingNode));

            System.out.println(message);

            throw new DuplicateIdentifierException(message, existing, td);
        }
    }

    private ParsedSchema parse() throws Exception
    {
        System.out.println("Parsing: " + schema.getSchema());

        for (TypeDeclaration td : schema.getTypeDelcarations())
        {

            // root types must all have schema-wide unique names
            checkUnique(td);

            if (td instanceof SimpleTypeDeclaration)
            {
                SimpleTypeDeclaration simpleType = (SimpleTypeDeclaration) td;
                rootSimpleTypes.put(simpleType.getName(), simpleType);
            }
            else if (td instanceof EnumDeclaration)
            {
                EnumDeclaration enumType = (EnumDeclaration) td;
                rootEnumerations.put(enumType.getName(), enumType);
            }
            else if (td instanceof SetDeclaration)
            {
                SetDeclaration setType = (SetDeclaration) td;
                rootSets.put(setType.getName(), setType);
            }
            else if (td instanceof CompositeTypeDeclaration)
            {
                CompositeTypeDeclaration ctd = (CompositeTypeDeclaration) td;
                rootComposites.put(ctd.getName(), ctd);
            }
            else throw new IllegalStateException(
                            "Don't know how to handle type: " + td.getClass().getName());
        }

        System.out.println("Root simple types: " + rootSimpleTypes.keySet());
        System.out.println("Root enumerations: " + rootEnumerations.keySet());
        System.out.println("Root sets (of choice): " + rootSets.keySet());
        System.out.println("Root composites: " + rootComposites.keySet());

        System.out.println("Processing root composites...");

        for (CompositeTypeDeclaration ctd : rootComposites.values())
        {
            parse(ctd, null);
        }

        return new ParsedSchema(schema);
    }

    private void parse(CompositeTypeDeclaration ctd, ParsedComposite container)
    {
        System.out.format("    composite: %s in %s...%n", ctd.getName(),
                        container != null ? container.getCompositeType().getName() : "[ROOT]");

        ParsedComposite parsedComposite = new ParsedComposite(ctd, container);

        // we go depth-first in order to reach leaf composites as we can
        // calculate the block length for them
        for (CompositeMember cm : ctd.getCompositeMembers())
        {
            if (cm instanceof CompositeTypeDeclaration)
            {
                parse((CompositeTypeDeclaration) cm, parsedComposite);
            }
        }

        // now we can build the field index for this composite; any neste
        // composites already have their block lengths resolved

        FieldIndex fieldIndex = parsedComposite.getFieldIndex();

        for (CompositeMember cm : ctd.getCompositeMembers())
        {
            if (cm instanceof MemberPrimitiveTypeDeclaration)
            {
                MemberPrimitiveTypeDeclaration m = (MemberPrimitiveTypeDeclaration) cm;
                fieldIndex.addPrimitiveField(m.getName(), m.getPrimitiveType());
            }
            else if (cm instanceof MemberRefTypeDeclaration)
            {
                MemberRefTypeDeclaration m = (MemberRefTypeDeclaration) cm;
                TypeDeclaration refTargetType = m.getType();
                if (refTargetType instanceof SimpleTypeDeclaration)
                {
                    SimpleTypeDeclaration st = (SimpleTypeDeclaration) refTargetType;
                    
                }
            }
            else if (cm instanceof EnumDeclaration)
            {
            }
            else if (cm instanceof SetDeclaration)
            {
            }
            else if (cm instanceof CompositeTypeDeclaration)
            {
            }
            else throw new IllegalStateException(
                            "Don't know how to handle type: " + cm.getClass().getName());
        }
    }
}
