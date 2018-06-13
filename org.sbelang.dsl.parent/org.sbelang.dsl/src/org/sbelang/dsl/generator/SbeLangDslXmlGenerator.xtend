/*
 * generated by Xtext 2.13.0
 */
package org.sbelang.dsl.generator

import java.nio.ByteOrder
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.generator.intermediate.ImMessageSchema
import org.sbelang.dsl.generator.xml.XmlMessageSchema
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberCharTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberNumericTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.NumericOptionalModifiers
import org.sbelang.dsl.sbeLangDsl.SimpleTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.NumericConstantModifiers
import org.sbelang.dsl.sbeLangDsl.CharOptionalModifiers
import org.sbelang.dsl.sbeLangDsl.CharConstantModifiers
import org.sbelang.dsl.sbeLangDsl.MemberRefTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.CompositeMember
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.VersionModifiers
import org.sbelang.dsl.sbeLangDsl.SetDeclaration

/**
 * Generates XML from your model files on save.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#code-generation
 */
class SbeLangDslXmlGenerator extends SbeLangDslBaseGenerator {

    public static val genXml = Boolean.valueOf(
        System.getProperty(typeof(SbeLangDslGenerator).package.name + ".genXml", "true"))

    override void compile(ImMessageSchema imSchema, IFileSystemAccess2 fsa, IGeneratorContext context) {
        if(!genXml) return;

        val xmlSchema = new XmlMessageSchema(imSchema)

        fsa.generateFile(
            imSchema.schemaName + '.xml',
            '''
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <sbe:messageSchema xmlns:sbe="http://fixprotocol.io/2016/sbe"
                    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
                    xsi:schemaLocation="http://fixprotocol.io/2016/sbe/sbe.xsd"
                    
                    package="«imSchema.schemaName»"
                    id="«imSchema.schemaId»" version="«imSchema.schemaVersion»"«optionalAttrs(xmlSchema)»>
                    
                    <types>
                        «FOR type : imSchema.rawSchema.typeDelcarations.filter(SimpleTypeDeclaration)»
                            «compile(type)»
                        «ENDFOR»
                        
                        «FOR type : imSchema.rawSchema.typeDelcarations.filter(EnumDeclaration)»
                            «compile(type)»
                        «ENDFOR»
                        
                        «FOR type : imSchema.rawSchema.typeDelcarations.filter(SetDeclaration)»
                            «compile(type)»
                        «ENDFOR»
                        
                        «FOR compositeType : imSchema.rawSchema.typeDelcarations.filter(CompositeTypeDeclaration)»
                            «compile(compositeType)»
                        «ENDFOR»
                    </types>
                    
                </sbe:messageSchema>
            '''
        )
    }

    private def compile(SimpleTypeDeclaration std) {
        '''
            <type name="«std.name»" primitiveType="«std.primitiveType»"«simpleTypeLength(std)»«versionAttrs(std.versionModifiers)»/>
        '''
    }

    private def simpleTypeLength(SimpleTypeDeclaration std) {
        '''«IF std.length !== null» length="«std.length»"«ENDIF»'''
    }

    private def versionAttrs(VersionModifiers vm) {
        if (vm !== null) {

            val sinceV = vm.sinceVersion;
            val depV = vm.deprecatedSinceVersion;

            '''«IF sinceV !== null» sinceVersion="«sinceV»"«ENDIF»«IF depV !== null» deprecated="«depV»"«ENDIF»"'''
        } else {
            ""
        }
    }

    private def optionalAttrs(XmlMessageSchema xmlSchema) {
        '''«headerTypeAttr(xmlSchema.imSchema)»«byteOrderAttr(xmlSchema)»'''
    }

    private def headerTypeAttr(ImMessageSchema imSchema) {
        '''«IF imSchema.headerTypeName !== null» headerType="«imSchema.headerTypeName»"«ENDIF»'''
    }

    private def byteOrderAttr(XmlMessageSchema xmlMessageSchema) {
        '''«IF xmlMessageSchema.imSchema.schemaByteOrder !== ByteOrder.LITTLE_ENDIAN» byteOrder="«xmlMessageSchema.byteOrderAttribute»"«ENDIF»'''
    }

    private def String compile(CompositeTypeDeclaration ctd) {
        '''
            <composite name="«ctd.name»"«versionAttrs(ctd.versionModifiers)»>
                «FOR cm : ctd.compositeMembers»
                «compile(cm)»
                «ENDFOR»
            </composite>
        '''
    }

    private def compile(CompositeMember cm) {
        if (cm instanceof MemberTypeDeclaration)
            compile(cm /* as MemberTypeDeclaration */)
        else if (cm instanceof CompositeTypeDeclaration)
            compile(cm /* as CompositeTypeDeclaration */)
        else 
            throw new IllegalStateException("Unsupported composite member: " + cm.class.name)
    }

    private def compile(EnumDeclaration ed) {
        '''
            <enum name="«ed.enumName»" encodingType="«ed.encodingType»"«versionAttrs(ed.versionModifiers)»>
                «FOR enumVal : ed.enumValues»
                <validValue name="«enumVal.name»">«enumVal.value»</validValue>
                «ENDFOR»
            </enum>
        '''
    }

    private def compile(SetDeclaration sd) {
        '''
            <set name="«sd.setName»" encodingType="«sd.encodingType»"«versionAttrs(sd.versionModifiers)»>
                «FOR setChoice : sd.setChoices»
                <choice name="«setChoice.name»">«setChoice.value»</choice>
                «ENDFOR»
            </set>
        '''
    }

    private def compile(MemberTypeDeclaration mtd) {
        switch mtd {
            MemberNumericTypeDeclaration:
                '''
                    <type name="«mtd.name»" primitiveType="«mtd.primitiveType»"«memberTypeLength(mtd)»«memberTypeRange(mtd)»«memberTypePresence(mtd)»«closeTag(mtd)»
                '''
            MemberCharTypeDeclaration:
                '''
                    <type name="«mtd.name»" primitiveType="«mtd.primitiveType»"«memberTypeLength(mtd)»«memberTypeRange(mtd)»«memberTypePresence(mtd)»«closeTag(mtd)»
                '''
            MemberRefTypeDeclaration:
                '''
                    <ref name="«mtd.name»" type="«mtd.type.name»"«memberTypeLength(mtd)»«memberTypeRange(mtd)»«memberTypePresence(mtd)»«closeTag(mtd)»
                '''
            EnumDeclaration:
                compile(mtd)
            default: '''TODO'''
        }
    }

    private def memberTypeLength(MemberTypeDeclaration mtd) {
        if (mtd instanceof MemberCharTypeDeclaration)
            '''«IF mtd.length !== null» length="«mtd.length»"«ENDIF»'''
        else
            ""
    }

    private def memberTypeRange(MemberTypeDeclaration mtd) {
        if (mtd instanceof MemberNumericTypeDeclaration) {
            if (mtd.rangeModifiers !== null)
                '''«IF mtd.rangeModifiers.min !== null» minValue="«mtd.rangeModifiers.min»"«ENDIF»«IF mtd.rangeModifiers.max !== null» maxValue="«mtd.rangeModifiers.max»"«ENDIF»'''
        } else if (mtd instanceof MemberCharTypeDeclaration) {
            if (mtd.rangeModifiers !== null)
                '''«IF mtd.rangeModifiers.min !== null» minValue="«mtd.rangeModifiers.min»"«ENDIF»«IF mtd.rangeModifiers.max !== null» maxValue="«mtd.rangeModifiers.max»"«ENDIF»'''
        } else {
            ""
        }
    }

    private def memberTypePresence(MemberTypeDeclaration mtd) {
        if (mtd instanceof MemberNumericTypeDeclaration) {
            if (mtd.presence instanceof NumericOptionalModifiers) {
                val NumericOptionalModifiers t = mtd.presence as NumericOptionalModifiers
                if (t.
                    isOptional) ''' presence="optional"''' else '''«IF t.nullValue !== null» presence="optional" nullValue="«t.nullValue»"«ENDIF»'''
            } else if (mtd.presence instanceof NumericConstantModifiers) {
                ''' presence="constant"'''
            }
        } else if (mtd instanceof MemberCharTypeDeclaration) {
            if (mtd.presence instanceof CharOptionalModifiers) {
                val CharOptionalModifiers t = mtd.presence as CharOptionalModifiers
                if (t.
                    isOptional) ''' presence="optional"''' else '''«IF t.nullValue !== null» presence="optional" nullValue="«t.nullValue»"«ENDIF»'''
            } else if (mtd.presence instanceof CharConstantModifiers) {
                ''' presence="constant"'''
            }
        } else {
            ""
        }
    }

    private def closeTag(MemberTypeDeclaration mtd) {
        if (mtd instanceof MemberNumericTypeDeclaration) {
            if (mtd.presence instanceof NumericConstantModifiers) {
                val NumericConstantModifiers t = mtd.presence as NumericConstantModifiers
                '''>«t.constantValue»</type>'''
            } else {
                "/>"
            }
        } else {
            "/>"
        }
    }
}
