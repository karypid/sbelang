package org.sbelang.dsl.generator.intermediate

import java.nio.ByteOrder
import java.nio.file.Path
import java.nio.file.Paths
import java.util.HashMap
import java.util.Map
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberRefTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.MessageSchema
import org.sbelang.dsl.sbeLangDsl.OptionalSchemaAttrs
import org.sbelang.dsl.sbeLangDsl.SetDeclaration
import org.sbelang.dsl.sbeLangDsl.TypeDeclaration

class ImMessageSchema {
    static val DEFAULT_HEADER_TYPE_NAME = "org.sbelang.DefaultHeader"

    public val MessageSchema rawSchema

    public val String schemaName
    public val int schemaId
    public val int schemaVersion
    public val ByteOrder schemaByteOrder
    public val String schemaByteOrderConstant;
    public val String headerTypeName

    public val Path packagePath

    // sets, enums and composites (even nested ones) must have unique
    // names (case-insensitive); we build a type index here using their
    // unqualified name in upper case as the key
    val Map<String, TypeDeclaration> allGlobalTypesByUname = new HashMap()

    // this map is populated using the same key as all global types
    // (upper case name) for types that manifest blocks of fields
    // (composites, messages) in order to keep track of field offsets
    // and lengths within each such structure
    val Map<String, FieldIndex> allFieldIndexesByUname = new HashMap()

    public val Map<String, EnumDeclaration> fqnEnumsMap = new HashMap();
    public val Map<String, CompositeTypeDeclaration> fqnCompositesMap = new HashMap();

    new(MessageSchema rawSchema) {
        this.rawSchema = rawSchema

        this.schemaName = rawSchema.schema.name
        this.schemaId = rawSchema.schema.id
        this.schemaVersion = rawSchema.schema.version
        this.schemaByteOrder = parseByteOrder(rawSchema.schema.optionalAttrs)
        this.schemaByteOrderConstant = if(schemaByteOrder === ByteOrder.BIG_ENDIAN) "BIG_ENDIAN" else "LITTLE_ENDIAN"
        this.headerTypeName = parseHeaderTypeName(rawSchema.schema.optionalAttrs)

        this.packagePath = {
            val String[] components = schemaName.split("\\.")
            val schemaPath = Paths.get(".", components)
            Paths.get(".").relativize(schemaPath).normalize
        }

        buildTypesIndex()
    }

    def getFieldIndex(String name) {
        return allFieldIndexesByUname.get(name.toUpperCase)
    }

    private def buildTypesIndex() {
        rawSchema.typeDelcarations.forEach [ td |
            switch td {
//                SimpleTypeDeclaration:
                EnumDeclaration: {
                    addToGlobalIndex(td.name, td)
                    allGlobalTypesByUname.put(td.name.toUpperCase, td)
                    fqnEnumsMap.put(schemaName + "." + td.name, td)
                }
//                SetDeclaration:
                CompositeTypeDeclaration: {
                    collectComposites(td, schemaName + ".", fqnCompositesMap)
                }
//                default:
            }
        ]
    }

    private def addToGlobalIndex(String name, TypeDeclaration td) {
        val uname = name.toUpperCase
        val existing = allGlobalTypesByUname.get(uname)
        if (existing !== null) {
            throw new DuplicateIdentifierException("Name collision (case-insensitive) for: " + uname, existing, td)
        }

        allGlobalTypesByUname.put(uname, td)

        // create field index where applicable
        if (td instanceof CompositeTypeDeclaration)
            allFieldIndexesByUname.put(uname, new FieldIndex())
//        else if (td instanceof MessageDeclaration)
//            allFieldIndexesByUname.put(uname, new MessageFieldIndex(td))
    }

    private def void collectComposites(CompositeTypeDeclaration rootComposite, String prefix,
        Map<String, CompositeTypeDeclaration> map) {

        addToGlobalIndex(rootComposite.name, rootComposite)

        val compositeName = rootComposite.name.toFirstUpper
        fqnCompositesMap.put(prefix + compositeName, rootComposite)

        val fi = allFieldIndexesByUname.get(rootComposite.name.toUpperCase)

        rootComposite.compositeMembers.forEach [ cm |
            switch cm {
                MemberRefTypeDeclaration: {
                    fi.addPrimitiveField(cm.name, cm.primitiveType)
                }
                EnumDeclaration: {
                    addToGlobalIndex(cm.name, cm)
                    allGlobalTypesByUname.put(cm.name.toUpperCase, cm)
                    fqnEnumsMap.put(schemaName + "." + cm.name, cm)
                }
                SetDeclaration: {
                }
                CompositeTypeDeclaration: {
                    collectComposites(cm, prefix + compositeName + ".", map)
                }
                default:
                    throw new IllegalStateException("Dont know how to handle: " + cm.class.name)
            }
        ]
    }

    private def parseByteOrder(OptionalSchemaAttrs attrs) {
        if (rawSchema.schema.optionalAttrs === null)
            ByteOrder.LITTLE_ENDIAN
        else if (rawSchema.schema.optionalAttrs.bigEndian)
            ByteOrder.BIG_ENDIAN
        else
            ByteOrder.LITTLE_ENDIAN
    }

    private def parseHeaderTypeName(OptionalSchemaAttrs attrs) {
        if (rawSchema.schema.optionalAttrs === null)
            DEFAULT_HEADER_TYPE_NAME
        else
            rawSchema.schema.optionalAttrs.headerType;
    }

}
