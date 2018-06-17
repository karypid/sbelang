package org.sbelang.dsl

import java.math.BigDecimal
import java.math.BigInteger
import java.util.Arrays
import java.util.Optional

class SbeLangDslValueUtils {
    public static val char SINGLE_QUOTE = '\''
    public static val char BACKSLASH = '\\'

    static def isValidCharLiteral(String literal) {
        if (literal === null)
            false
        else if ((literal.length() == 3) && (literal.charAt(0) === SINGLE_QUOTE) &&
            (literal.charAt(2) === SINGLE_QUOTE))
            true
        else if ((literal.length() == 6) && (literal.charAt(0) === SINGLE_QUOTE) && (literal.charAt(1) === BACKSLASH) &&
            (literal.charAt(5) === SINGLE_QUOTE))
            true
        else
            false
    }

    static def isValidLiteral(String literal, String primitiveType) {
        switch primitiveType {
            case 'char':
                isValidCharLiteral(literal)
            case 'int8',
            case 'int16',
            case 'int32',
            case 'int64',
            case 'uint8',
            case 'uint16',
            case 'uint32',
            case 'uint64': {
                val i = parseBigInteger(literal).orElse(null)

                if (i !== null) {
                    val max = maxValue(primitiveType)
                    val min = minValue(primitiveType)
                    var d = new BigDecimal(i)
                    return (max.compareTo(d) >= 0) && (min.compareTo(d) <= 0)
                }

                false
            }
            default:
                false
        }
    }

    static def maxValue(String primitiveType) {
        val byte FF = 0xff as byte
        val byte[] input = #[FF, FF, FF, FF, FF, FF, FF, FF] // 64 bits, signed long = -1
        switch primitiveType {
            case 'int8': new BigDecimal(Byte.MAX_VALUE)
            case 'int16': new BigDecimal(Short.MAX_VALUE)
            case 'int32': new BigDecimal(Integer.MAX_VALUE)
            case 'int64': new BigDecimal(Long.MAX_VALUE)
            case 'uint8': new BigDecimal(new BigInteger(1, Arrays.copyOfRange(input, 0, 1)))
            case 'uint16': new BigDecimal(new BigInteger(1, Arrays.copyOfRange(input, 0, 2)))
            case 'uint32': new BigDecimal(new BigInteger(1, Arrays.copyOfRange(input, 0, 4)))
            case 'uint64': new BigDecimal(new BigInteger(1, Arrays.copyOfRange(input, 0, 8)))
        }
    }

    static def minValue(String primitiveType) {
        switch primitiveType {
            case 'int8': new BigDecimal(Byte.MIN_VALUE)
            case 'int16': new BigDecimal(Short.MIN_VALUE)
            case 'int32': new BigDecimal(Integer.MIN_VALUE)
            case 'int64': new BigDecimal(Long.MIN_VALUE)
            case 'uint8': BigDecimal.ZERO
            case 'uint16': BigDecimal.ZERO
            case 'uint32': BigDecimal.ZERO
            case 'uint64': BigDecimal.ZERO
        }
    }

    static def Optional<Character> parseCharacter(String toParse) {
        if (toParse === null)
            Optional.empty
        else if ((toParse.length === 3) && (toParse.charAt(0) === SINGLE_QUOTE) && (toParse.charAt(2) === SINGLE_QUOTE))
            Optional.of(toParse.charAt(1))
        else if ((toParse.length() == 6) && (toParse.charAt(0) === SINGLE_QUOTE) && (toParse.charAt(1) === BACKSLASH) &&
            (toParse.charAt(5) === SINGLE_QUOTE)) {
            val byte ascii = Byte.valueOf(toParse.substring(2, 5))
            // TODO: how on earth does xtend cast to char primitive?
            val byte[] input = #[ascii]
            val char c = new String(input).charAt(0)
            Optional.of(c)
        } else
            Optional.empty
    }

    static def Optional<BigInteger> parseBigInteger(String toParse) {
        try {
            return Optional.of(new BigInteger(toParse, 10));
        } catch (NumberFormatException e) {
            return Optional.empty();
        }
    }

    static def Optional<BigDecimal> parseBigDecimal(String toParse) {
        try {
            return Optional.of(new BigDecimal(toParse));
        } catch (NumberFormatException e) {
            return Optional.empty();
        }
    }
}
