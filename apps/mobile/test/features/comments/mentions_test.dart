import 'package:flowboard/features/comments/domain/mentions.dart';
import 'package:flowboard/features/workspaces/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

const anna = MemberUser(id: 'a', email: 'anna@example.com', name: 'Anna');
const annaLee = MemberUser(
  id: 'al',
  email: 'lee@example.com',
  name: 'Anna Lee',
);
const timur = MemberUser(id: 't', email: 'timur@example.com', name: 'Тимур');
const List<MemberUser> team = [anna, annaLee, timur];

void main() {
  group('findMentions', () {
    test('finds members in text order', () {
      expect(mentionedIds('@Тимур, ask @Anna.', team), ['t', 'a']);
    });

    test('prefers the longest name', () {
      expect(mentionedIds('@Anna Lee and @Anna', team), ['al', 'a']);
      final matches = findMentions('hi @Anna Lee!', team);
      expect(matches.single.start, 3);
      expect(matches.single.end, 12);
    });

    test('needs a standalone, exact @Name', () {
      expect(mentionedIds('@Annabel', team), isEmpty);
      expect(mentionedIds('mail@Anna', team), isEmpty);
      expect(mentionedIds('@anna', team), isEmpty);
      expect(mentionedIds('Anna', team), isEmpty);
    });

    test('lists each member once', () {
      expect(mentionedIds('@Anna @Anna', team), ['a']);
    });
  });

  group('typing a mention', () {
    test('finds the @query before the cursor', () {
      final query = mentionQueryAt('Ask @An', 7)!;
      expect(query.start, 4);
      expect(query.query, 'An');
      expect(mentionQueryAt('@', 1)!.query, '');
      expect(mentionQueryAt('Ask @An', 3), isNull);
      expect(mentionQueryAt('mail@An', 7), isNull);
      expect(mentionQueryAt('@An\nx', 5), isNull);
    });

    test('suggests by any word of the name or by e-mail', () {
      expect(mentionSuggestions('an', team), [anna, annaLee]);
      expect(mentionSuggestions('lee', team), [annaLee]);
      expect(mentionSuggestions('тим', team), [timur]);
      expect(mentionSuggestions('', team, limit: 2), [anna, annaLee]);
    });

    test('replaces the query with the full name', () {
      const text = 'Ask @An please';
      final result = insertMention(
        text,
        mentionQueryAt(text, 7)!,
        7,
        'Anna Lee',
      );
      expect(result.text, 'Ask @Anna Lee  please');
      expect(result.cursor, 14);
    });
  });
}
