import re
import unicodedata


class TextQualityAnalyzer:
    """Analyzes text quality to determine if OCR enhancement is needed."""

    def needs_ocr_enhancement(self, text: str, check_formula: bool = False, check_encoding: bool = False) -> dict:
        """
        Determine if text needs OCR enhancement based on enabled options.
        
        Args:
            text: Text to analyze
            check_formula: Enable formula enhancement (Latin script/English with numbers)
            check_encoding: Enable character encoding fix
            
        Returns:
            Dict with 'encoding' and 'formula' boolean flags indicating enhancement needs
        """
        if not text or not text.strip():
            return {'encoding': False, 'formula': False}

        result = {'encoding': False, 'formula': False}

        # Character encoding fix - check for replacement characters
        if check_encoding:
            result['encoding'] = self._has_encoding_issues(text)

        # Formula enhancement - check for Latin letters with digits
        if check_formula:
            result['formula'] = self._needs_formula_enhancement(text)

        return result

    def _has_encoding_issues(self, text: str) -> bool:
        """Check if text has character encoding issues."""
        # Check for known replacement characters
        error_chars = ['', '�', '', '\x00', '\x1A', '\ufffd']  # U+FFFD, U+FFFC, U+F0A4, NULL, SUB
        if any(char in text for char in error_chars):
            return True

        # Check for other non-ASCII characters that might indicate encoding issues
        if re.search(r'[^\x00-\x7F]', text) and not self._is_valid_non_ascii(text):
            return True

        return False

    def _needs_formula_enhancement(self, text: str) -> bool:
        """Check if text needs formula enhancement (Latin letters with digits)."""
        has_digit = any(c.isdigit() for c in text)
        has_latin = any('LATIN' in unicodedata.name(c, '') for c in text if c.isalpha())

        return has_latin and has_digit

    def _is_valid_non_ascii(self, text: str) -> bool:
        """Check if non-ASCII characters are valid (e.g., proper Arabic, accented characters)."""
        for char in text:
            if ord(char) > 127:  # Non-ASCII
                try:
                    name = unicodedata.name(char)
                    # Allow common valid non-ASCII characters
                    if any(script in name for script in ['ARABIC', 'LATIN', 'MATHEMATICAL']):
                        continue
                    # If we can't categorize it as valid, it might be an encoding issue
                    return False
                except ValueError:
                    # Character has no name, likely encoding issue
                    return False
        return True
