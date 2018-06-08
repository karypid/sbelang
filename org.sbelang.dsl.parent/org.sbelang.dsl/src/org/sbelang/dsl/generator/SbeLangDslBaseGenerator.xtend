/*
 * generated by Xtext 2.13.0
 */
package org.sbelang.dsl.generator

import org.eclipse.xtext.generator.AbstractGenerator
import org.sbelang.dsl.sbeLangDsl.CompositeType
import org.sbelang.dsl.sbeLangDsl.EncodedDataType
import org.sbelang.dsl.sbeLangDsl.EnumType
import org.sbelang.dsl.sbeLangDsl.TypeDeclaration

/**
 * Base class for SBE generators
 */
abstract class SbeLangDslBaseGenerator extends AbstractGenerator {
    protected static val String LITTLE_ENDIAN_BYTE_ORDER = "littleEndian"
    protected static val String OPTIONAL_PRESENCE_MODIFIER = "?"

    protected val char CHAR_LITERAL_DELIMITER = '\''

    def boolean isOptional(EncodedDataType type) {
        type.presence !== null && OPTIONAL_PRESENCE_MODIFIER == type.presence
    }

    def boolean isConstant(EncodedDataType type) {
        type.presence !== null && OPTIONAL_PRESENCE_MODIFIER != type.presence
    }

    def isConstant(TypeDeclaration type) {
        switch (type) {
            EncodedDataType:
                isConstant(type)
            EnumType:
                isConstant(type.enumEncodingType)
            CompositeType:
                false
            default:
                throw new IllegalArgumentException('''Can't handle field [«type.name»] of type [«type.class.name»]''')
        }
    }

    def boolean isRequired(EncodedDataType type) {
        type.presence === null
    }
}
