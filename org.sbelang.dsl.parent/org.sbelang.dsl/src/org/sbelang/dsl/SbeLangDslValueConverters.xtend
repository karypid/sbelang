package org.sbelang.dsl

import org.eclipse.xtext.common.services.DefaultTerminalConverters
import org.eclipse.xtext.conversion.IValueConverter
import org.eclipse.xtext.conversion.ValueConverter
import org.eclipse.xtext.conversion.ValueConverterException
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.util.Strings

class SbeLangDslValueConverters extends DefaultTerminalConverters {
    static val char SINGLE_QUOTE = '\''

    @ValueConverter(rule="OptionalChar")
    def IValueConverter<Character> ElementBound() {

        return new IValueConverter<Character>() {
            override toString(Character value) throws ValueConverterException {
                return "'" + value + "'";
            }

            override toValue(String string, INode node) throws ValueConverterException {
                if (Strings.isEmpty(string))
                    throw new ValueConverterException("Couldn't convert empty string to char", node, null);

                val str = string.trim();

                if ((str.length() != 3) || (str.charAt(0) !== SINGLE_QUOTE) || (str.charAt(2) !== SINGLE_QUOTE))
                    throw new ValueConverterException("Literal is malformed (not single-quoted character)", node, null);
                return str.charAt(1);
            }
        };
        
    }
}
