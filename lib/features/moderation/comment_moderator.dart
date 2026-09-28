// T15: preservar original no banco; mascarar somente na apresentação.
const _blockedWords = {'idiota', 'imbecil', 'estupido', 'merda'};

String moderateComment(String text) {
	final maskedRanges = <(int, int)>[];
	var tokenStart = -1;
	var tokenEnd = -1;
	var token = StringBuffer();
	var offset = 0;

	void finishToken() {
		if (tokenStart >= 0 && _blockedWords.contains(token.toString())) {
			maskedRanges.add((tokenStart, tokenEnd));
		}
		tokenStart = -1;
		tokenEnd = -1;
		token = StringBuffer();
	}

	for (final rune in text.runes) {
		final character = String.fromCharCode(rune);
		final normalized = _normalizeCharacter(character);
		if (_isWordCharacter(normalized)) {
			if (tokenStart < 0) tokenStart = offset;
			token.write(normalized);
			tokenEnd = offset + character.length;
		} else if (_isCombiningMark(rune)) {
			if (tokenStart >= 0) tokenEnd = offset + character.length;
		} else {
			finishToken();
		}
		offset += character.length;
	}
	finishToken();

	if (maskedRanges.isEmpty) return text;
	final result = StringBuffer();
	var cursor = 0;
	for (final (start, end) in maskedRanges) {
		result
			..write(text.substring(cursor, start))
			..write('***');
		cursor = end;
	}
	result.write(text.substring(cursor));
	return result.toString();
}

String _normalizeCharacter(String character) {
	final lower = character.toLowerCase();
	return switch (lower) {
		'á' || 'à' || 'â' || 'ã' || 'ä' => 'a',
		'é' || 'è' || 'ê' || 'ë' => 'e',
		'í' || 'ì' || 'î' || 'ï' => 'i',
		'ó' || 'ò' || 'ô' || 'õ' || 'ö' => 'o',
		'ú' || 'ù' || 'û' || 'ü' => 'u',
		'ç' => 'c',
		_ => lower,
	};
}

bool _isWordCharacter(String character) {
	if (character.length != 1) return false;
	final code = character.codeUnitAt(0);
	return (code >= 0x61 && code <= 0x7a) ||
			(code >= 0x30 && code <= 0x39) ||
			code == 0x5f;
}

bool _isCombiningMark(int rune) => rune >= 0x0300 && rune <= 0x036f;
