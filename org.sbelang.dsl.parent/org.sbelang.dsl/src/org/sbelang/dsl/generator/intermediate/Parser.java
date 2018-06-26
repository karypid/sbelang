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
import org.sbelang.dsl.sbeLangDsl.MemberRefTypeDeclaration;
import org.sbelang.dsl.sbeLangDsl.MessageSchema;
import org.sbelang.dsl.sbeLangDsl.SetDeclaration;
import org.sbelang.dsl.sbeLangDsl.SimpleTypeDeclaration;
import org.sbelang.dsl.sbeLangDsl.TypeDeclaration;
import org.sbelang.dsl.sbeLangDsl.impl.SimpleTypeDeclarationImpl;

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
    // referenced anywhere (messages, groups, nested composites...); furthermore
    // the nested container typer (enum/set/composite) which are defined inline
    // within root composites must also have globally unique names for
    // convenience and flexibility in generating code (e.g. can use a static
    // class at the schema package level rather than requiring a nested inner
    // class within the containing composite)
    private final Map<String, TypeDeclaration> allRootNames;

    private final Map<String, ParsedComposite> allParsedComposites;

    private Parser(MessageSchema schema)
    {
        super();

        this.schema = schema;

        this.rootSimpleTypes = new LinkedHashMap<>();
        this.rootEnumerations = new LinkedHashMap<>();
        this.rootSets = new LinkedHashMap<>();
        this.rootComposites = new LinkedHashMap<>();

        this.allRootNames = new LinkedHashMap<>();
        this.allParsedComposites = new LinkedHashMap<>();

        // we define simple types for all primitives
        for (String pt : SbeUtils.PRIMITIVE_TYPES)
        {
            SimpleTypeDeclarationImpl st = new SimpleTypeDeclarationImpl() {
                {
                    setPrimitiveType(pt);
                    setName(pt);
                    setLength(1);
                }
            };

            rootSimpleTypes.put(pt, st);
            allRootNames.put(pt.toUpperCase(), st);
        }
    }

    private ParsedSchema parse() throws Exception
    {
        System.out.println("Parsing: " + schema.getSchema());

        for (TypeDeclaration td : schema.getTypeDelcarations())
        {

            // root types must all have schema-wide unique names
            checkRootUnique(td);

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

        System.out.println("All root names: " + allRootNames.keySet());

        System.out.println("Processing root composites...");

        for (CompositeTypeDeclaration ctd : rootComposites.values())
        {
            parseComposite(ctd, null);
        }

        System.out.println("All root names: " + allRootNames.keySet());

        return new ParsedSchema(schema, allRootNames, allParsedComposites);
    }

    private void parseComposite(CompositeTypeDeclaration ctd, ParsedComposite container)
                    throws DuplicateIdentifierException, AttributeErrorException
    {
        System.out.format("    composite: %s in %s...%n", ctd.getName(),
                        container != null ? container.getCompositeType().getName() : "[ROOT]");

        ParsedComposite parsedComposite = new ParsedComposite(ctd, container);

        // we go depth-first in order to reach leaf composites as we can
        // calculate the block length for them; we only lookt at inline
        // composites at this point and ignore everything else
        for (CompositeMember cm : ctd.getCompositeMembers())
        {
            if (cm instanceof CompositeTypeDeclaration) // inline composite
            {
                CompositeTypeDeclaration nestedCtd = (CompositeTypeDeclaration) cm;
                // nested composites must have unique names across schema
                checkRootUnique(nestedCtd);
                parseComposite(nestedCtd, parsedComposite);
            }
        }

        // now we can build the field index for this composite; any neste
        // composites already have their block lengths resolved

        FieldIndex fieldIndex = parsedComposite.getFieldIndex();

        for (CompositeMember cm : ctd.getCompositeMembers())
        {
            if (cm instanceof MemberRefTypeDeclaration)
            {
                MemberRefTypeDeclaration m = (MemberRefTypeDeclaration) cm;

                // references can be made to primitive types directly as a
                // special case. also, some attributes are present in the
                // grammar for that case only. we need to check for illegal
                // stuff first before proceeding...

                if (m.getLength() != null)
                {
                    // length is only allowed when using a primitive type...
                    if (m.getPrimitiveType() == null)
                    {
                        String message = String.format("Length is not allowed on [%s] at %s",
                                        m.getName(), SbeUtils.location(m));
                        throw new AttributeErrorException(message, m);
                    }
                }

                if (m.getPrimitiveType() != null)
                {
                    int length = m.getLength() == null ? 1 : m.getLength();
                    fieldIndex.addPrimitiveField(m.getName(), m.getPrimitiveType(), length, m);
                }
                else
                {
                    TypeDeclaration refTargetType = m.getType();
                    if (refTargetType instanceof SimpleTypeDeclaration)
                    {
                        SimpleTypeDeclaration st = (SimpleTypeDeclaration) refTargetType;
                        int stLength = st.getLength() == null ? 1 : st.getLength();
                        fieldIndex.addPrimitiveField(m.getName(), st.getPrimitiveType(), stLength,
                                        m);
                    }
                    else if (refTargetType instanceof EnumDeclaration)
                    {
                        EnumDeclaration ed = (EnumDeclaration) refTargetType;
                        String encodingType = ed.getEncodingType();
                        SimpleTypeDeclaration st = rootSimpleTypes.get(encodingType);
                        fieldIndex.addPrimitiveField(ed.getName(), st.getPrimitiveType(), 1, m);
                    }
                    else if (refTargetType instanceof SetDeclaration)
                    {
                        SetDeclaration sd = (SetDeclaration) refTargetType;
                        String encodingType = sd.getEncodingType();
                        SimpleTypeDeclaration st = rootSimpleTypes.get(encodingType);
                        fieldIndex.addPrimitiveField(sd.getName(), st.getPrimitiveType(), 1, m);
                    }
                    else if (refTargetType instanceof CompositeTypeDeclaration)
                    {
                        CompositeTypeDeclaration reftCtd = (CompositeTypeDeclaration) refTargetType;
                        ParsedComposite refParsedComposite = allParsedComposites
                                        .get(reftCtd.getName());
                        if (refParsedComposite.getCompositeType() != reftCtd)
                            throw new IllegalStateException("Composite index lookup mismatch");
                        fieldIndex.addCompositeField(m.getName(), reftCtd,
                                        refParsedComposite.getFieldIndex().getTotalOctetLength());
                    }
                    else throw new IllegalStateException("Don't know how to handle type: "
                                    + refTargetType.getClass().getName());

                }
            }
            else if (cm instanceof EnumDeclaration)
            {
                EnumDeclaration ed = (EnumDeclaration) cm;
                checkRootUnique(ed);
                fieldIndex.addPrimitiveField(ed.getName(), ed.getEncodingType(), 1, ed);
            }
            else if (cm instanceof SetDeclaration)
            {
                SetDeclaration sd = (SetDeclaration) cm;
                checkRootUnique(sd);
                fieldIndex.addPrimitiveField(sd.getName(), sd.getEncodingType(), 1, sd);
            }
            else if (cm instanceof CompositeTypeDeclaration)
            {
                // we have already done a pass above to parse and create the
                // field index, so we should be able to locate it in the map
                CompositeTypeDeclaration nestedCtd = (CompositeTypeDeclaration) cm;
                ParsedComposite nestedParsedComposite = allParsedComposites
                                .get(nestedCtd.getName());
                if (nestedParsedComposite.getCompositeType() != nestedCtd)
                    throw new IllegalStateException("Composite index lookup mismatch");
                fieldIndex.addCompositeField(nestedCtd.getName(), nestedCtd,
                                nestedParsedComposite.getFieldIndex().getTotalOctetLength());
            }
            else throw new IllegalStateException(
                            "Don't know how to handle type: " + cm.getClass().getName());
        }

        allParsedComposites.put(parsedComposite.getContainerName(), parsedComposite);
    }

    private void checkRootUnique(TypeDeclaration td) throws DuplicateIdentifierException
    {
        String caseInsensitiveName = td.getName().toUpperCase();

        TypeDeclaration existing = allRootNames.put(caseInsensitiveName, td);

        if (existing != null)
        {
            ICompositeNode collidingNode = NodeModelUtils.getNode(td);
            ICompositeNode existingNode = NodeModelUtils.getNode(existing);

            String message = String.format(
                            "At %s name [%s] collides with previously defined [%s] at %s (note: case-insensitive)",
                            SbeUtils.location(collidingNode), td.getName(), existing.getName(),
                            SbeUtils.location(existingNode));

            System.out.println(message);

            throw new DuplicateIdentifierException(message, existing, td);
        }
    }
}
