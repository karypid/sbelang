/*
 * generated by Xtext 2.13.0
 */
package org.sbelang.dsl.generator

import java.nio.ByteOrder
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import org.sbelang.dsl.generator.intermediate.ImMessageSchema
import org.sbelang.dsl.generator.xml.XmlMessageSchema
import org.sbelang.dsl.sbeLangDsl.CompositeMember
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.FieldDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberPrimitiveTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberRefTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.PresenceConstantModifier
import org.sbelang.dsl.sbeLangDsl.PresenceOptionalModifier
import org.sbelang.dsl.sbeLangDsl.SetDeclaration
import org.sbelang.dsl.sbeLangDsl.SimpleTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.VersionModifiers

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
                    
                    «FOR message : imSchema.rawSchema.messageDeclarations»
                        <message name="«message.block.name»" id="«message.block.id»">
                            «FOR field : message.block.fieldDeclarations»
                                «compile(field)»
                            «ENDFOR»
                        </message>
                    «ENDFOR»
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
            compile(cm /* as MemberTypeDeclaration */ )
        else if (cm instanceof CompositeTypeDeclaration)
            compile(cm /* as CompositeTypeDeclaration */ )
        else
            throw new IllegalStateException("Unsupported composite member: " + cm.class.name)
    }

    private def compile(EnumDeclaration ed) {
        '''
            <enum name="«ed.name»" encodingType="«ed.encodingType»"«versionAttrs(ed.versionModifiers)»>
                «FOR enumVal : ed.enumValues»
                    <validValue name="«enumVal.name»"«versionAttrs(enumVal.versionModifiers)»>«enumVal.value»</validValue>
                «ENDFOR»
            </enum>
        '''
    }

    private def compile(SetDeclaration sd) {
        '''
            <set name="«sd.name»" encodingType="«sd.encodingType»"«versionAttrs(sd.versionModifiers)»>
                «FOR setChoice : sd.setChoices»
                    <choice name="«setChoice.name»"«versionAttrs(setChoice.versionModifiers)»>«setChoice.value»</choice>
                «ENDFOR»
            </set>
        '''
    }

    private def compile(MemberTypeDeclaration mtd) {
        // TODO: handle nullValue
        switch mtd {
            MemberPrimitiveTypeDeclaration: '''
                <type name="«mtd.name»" primitiveType="«mtd.primitiveType»"«memberTypeLength(mtd)»«memberTypeRange(mtd)»«presenceAttrs(mtd.presence)»«closeTag("type", mtd.presence)»
            '''
            MemberRefTypeDeclaration: '''
                <ref name="«mtd.name»" type="«mtd.type.name»"«memberTypeLength(mtd)»«memberTypeRange(mtd)» />
            '''
            EnumDeclaration:
                compile(mtd)
            default: '''TODO'''
        }
    }

    private def memberTypeLength(MemberTypeDeclaration mtd) {
        if (mtd instanceof MemberPrimitiveTypeDeclaration)
            '''«IF mtd.length !== null» length="«mtd.length»"«ENDIF»'''
        else
            ""
    }

    private def memberTypeRange(MemberTypeDeclaration mtd) {
        if (mtd instanceof MemberPrimitiveTypeDeclaration) {
            if (mtd.rangeModifiers !== null)
                '''«IF mtd.rangeModifiers.min !== null» minValue="«mtd.rangeModifiers.min»"«ENDIF»«IF mtd.rangeModifiers.max !== null» maxValue="«mtd.rangeModifiers.max»"«ENDIF»'''
        } else {
            ""
        }
    }

    def compile(FieldDeclaration field) {
        '''
            <field name="«field.name»" id="«field.id»" type="«field.fieldType.name»"«presenceAttrs(field.presenceModifiers)»«versionAttrs(field.versionModifiers)»«closeTag("field", field.presenceModifiers)»
        '''
    }

    def closeTag(String tag, EObject presence) {
        switch presence {
            PresenceConstantModifier: '''>«presence.constantValue»</«tag»>'''
            // PresenceOptionalModifier
            default: '''/>'''
        }
    }

    private def presenceAttrs(Object presence) {
        switch presence {
            PresenceOptionalModifier: ''' presence="optional"'''
            PresenceConstantModifier: ''' presence="constant"'''
            default: ''''''
        }
    }
}
