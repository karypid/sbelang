/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 27 Jun 2018
 */
package org.sbelang.dsl

import java.nio.ByteOrder
import org.eclipse.emf.common.util.EList
import org.sbelang.dsl.generator.intermediate.ParsedSchema
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumValueDeclaration

/**
 * @author karypid
 * 
 */
class JavaGenerator {
    static val ENUM_NULL_VAL_NAME = "NULL_VAL"

    // these are used for encoding. here the unsigned integers are
    // mapped to the signed version as we simply cast when populating
    // buffer values.
    static def primitiveToJavaWireType(String sbePrimitive) {
        switch sbePrimitive {
            case 'char': 'byte' // sbe chars are ascii
            case 'int8': 'byte'
            case 'int16': 'short'
            case 'int32': 'int'
            case 'int64': 'long'
            case 'uint8': 'byte'
            case 'uint16': 'short'
            case 'uint32': 'int'
            case 'uint64': 'long'
            case 'float': 'float'
            case 'double': 'double'
            default: throw new IllegalArgumentException('No java WIRE type mapping for SBE primitive: ' + sbePrimitive)
        }
    }

    // these are used in parameters for convenience; here we have wider
    // types for unsigned values where possible (e.g. uint16 is int) to
    // facilitate ease of use, but uint64 naturally remains long as Java
    // has no wider primitive...
    //
    // notably for char we don't widen to java's char as that is a 
    // unicode 16-bit value whereas SBE char is ASCII, therefore we 
    // want to emphasize that...
    static def primitiveToJavaDataType(String sbePrimitive) {
        switch sbePrimitive {
            case 'char': 'byte'
            case 'int8': 'byte'
            case 'int16': 'short'
            case 'int32': 'int'
            case 'int64': 'long'
            case 'uint8': 'short'
            case 'uint16': 'int'
            case 'uint32': 'long'
            case 'uint64': 'long'
            case 'float': 'float'
            case 'double': 'double'
            default: throw new IllegalArgumentException('No java type mapping for SBE primitive: ' + sbePrimitive)
        }
    }

    static def generateMessageSchema(ParsedSchema parsedSchema) {
        val schemaByteOrderConstant = if(parsedSchema.schemaByteOrder ===
                ByteOrder.BIG_ENDIAN) "BIG_ENDIAN" else "LITTLE_ENDIAN"
        '''
            package  «parsedSchema.schemaName»;
            
            import java.nio.ByteOrder;
            
            public class MessageSchema
            {
                
                public static final int SCHEMA_ID = «parsedSchema.schemaId»;
                
                public static final int SCHEMA_VERSION = «parsedSchema.schemaVersion»;
                
                public static final ByteOrder BYTE_ORDER = ByteOrder.«schemaByteOrderConstant»;
                
            }
        '''
    }

    static def generateEnumDefinition(ParsedSchema parsedSchema, EnumDeclaration ed) {
        val enumName = ed.name.toFirstUpper
        val enumValueJavaType = primitiveToJavaDataType(ed.encodingType)

        // separate null if present and calculate literal
        val enumValuesWithoutNull = ed.enumValues.filter[ev|ev.name != ENUM_NULL_VAL_NAME]
        val explicitNull = ed.enumValues.findFirst[ev|ev.name == ENUM_NULL_VAL_NAME]
        val enumNullValueLiteral = if (isEnumWithExplicitNull(ed.enumValues))
                '''«explicitNull.value»'''
            else
                enumDefaultNullValueLiteral(ed.encodingType)
        '''
            package  «parsedSchema.schemaName»;
            
            public enum «enumName»
            {
                «FOR ev : enumValuesWithoutNull»
                    «ev.name» ( («enumValueJavaType») «ev.value» ),
                «ENDFOR»
                
                «ENUM_NULL_VAL_NAME» ( («enumValueJavaType») «enumNullValueLiteral» );
                
                public final «enumValueJavaType» value;
                
                private «enumName»( final «enumValueJavaType» value )
                {
                    this.value = value;
                }
                
                public «enumValueJavaType» value()
                {
                    return value;
                }
                
                public static «enumName» get ( final «enumValueJavaType» value )
                {
                    switch ( value )
                    {
                        «FOR ev : enumValuesWithoutNull»
                            case «ev.value»: return «ev.name»;
                        «ENDFOR»
                        case «enumNullValueLiteral»: return «ENUM_NULL_VAL_NAME»;
                        default:
                            throw new IllegalArgumentException ( "Unknown value: " + value );
                    }
                }
            }
        '''
    }

    private static def boolean isEnumWithExplicitNull(EList<EnumValueDeclaration> enumValues) {
        enumValues.exists[evd|evd.name == ENUM_NULL_VAL_NAME]
    }

    private static def enumDefaultNullValueLiteral(String enumEncodingType) {
        switch (enumEncodingType) {
            case 'char': '0'
            case 'uint8': '255'
            case 'uint16': '65535'
            default: throw new IllegalStateException("Encoding not supported for enums: " + enumEncodingType)
        }
    }

}