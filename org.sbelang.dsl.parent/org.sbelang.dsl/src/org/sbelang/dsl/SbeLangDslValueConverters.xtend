package org.sbelang.dsl

import org.eclipse.xtext.common.services.DefaultTerminalConverters
import org.eclipse.xtext.conversion.IValueConverter
import org.eclipse.xtext.conversion.ValueConverter
import org.eclipse.xtext.conversion.ValueConverterException
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.conversion.impl.AbstractToStringConverter

class SbeLangDslValueConverters extends DefaultTerminalConverters {

    @ValueConverter(rule="Name")
    def IValueConverter<String> IDValueConverter() {
        return new AbstractToStringConverter<String>() {
            override protected internalToValue(String value, INode node) throws ValueConverterException {
                if (value.startsWith("^")) value.substring(1)
                else value
            }
        };
    }

    @ValueConverter(rule="OptionalChar")
    def IValueConverter<Character> OptionalCharValueConverter() {
        return new IValueConverter<Character>() {
            override toString(Character value) throws ValueConverterException {
                return "'" + value + "'";
            }

            override toValue(String literal, INode node) throws ValueConverterException {
                val c = SbeLangDslValueUtils.parseCharacter(literal)
                if (c === null)
                    throw new ValueConverterException("Literal is malformed (not single-quoted character)", node, null);
                return c.get.charValue
            }
        };
    }
}
