package org.sbelang.dsl

import org.eclipse.xtext.common.services.DefaultTerminalConverters
import org.eclipse.xtext.conversion.IValueConverter
import org.eclipse.xtext.conversion.ValueConverter
import org.eclipse.xtext.conversion.ValueConverterException
import org.eclipse.xtext.nodemodel.INode

class SbeLangDslValueConverters extends DefaultTerminalConverters {
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
