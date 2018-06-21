package org.sbelang.dsl.generator.intermediate

import com.google.common.collect.Iterables
import java.io.File
import java.nio.ByteOrder
import java.nio.file.Path
import java.nio.file.Paths
import java.util.Collections
import java.util.HashMap
import java.util.Map
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.MessageSchema
import org.sbelang.dsl.sbeLangDsl.OptionalSchemaAttrs

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

        rawSchema.typeDelcarations.filter(EnumDeclaration).forEach [ ed |
            fqnEnumsMap.put(schemaName + "." + ed.name, ed)
        ]

        val topLevelComposites = rawSchema.typeDelcarations.filter(CompositeTypeDeclaration)
        collectComposites(topLevelComposites, schemaName + ".", fqnCompositesMap)
    }

    def filename(String filename) {
        packagePath.toString + File.separatorChar + filename
    }

    private def parseByteOrder(OptionalSchemaAttrs attrs) {
        if (rawSchema.schema.optionalAttrs === null)
            ByteOrder.LITTLE_ENDIAN
        else if (rawSchema.schema.optionalAttrs.bigEndian)
            ByteOrder.BIG_ENDIAN
        else
            ByteOrder.LITTLE_ENDIAN
    }

    private def void collectComposites(Iterable<CompositeTypeDeclaration> declarations, String prefix,
        Map<String, CompositeTypeDeclaration> map) {
        declarations.forEach [ ctd |
            val compositeName = ctd.name.toFirstUpper
            fqnCompositesMap.put(prefix + compositeName, ctd)
            collectComposites(ctd.compositeMembers.filter(CompositeTypeDeclaration), prefix + compositeName + ".", map)
        ]
    }

    private def parseHeaderTypeName(OptionalSchemaAttrs attrs) {
        if (rawSchema.schema.optionalAttrs === null)
            DEFAULT_HEADER_TYPE_NAME
        else
            rawSchema.schema.optionalAttrs.headerType;
    }
}
