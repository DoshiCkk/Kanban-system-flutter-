import 'package:flowboard/features/workspaces/domain/workspace.dart';

// Mentions (docs/realtime.md): the comment text keeps a readable `@Name`
// and `Comment.mentions` holds the ids of the members it names, so the text
// stays meaningful in notifications and for people without the member list.

final _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);

bool _isWordChar(String char) => _wordChar.hasMatch(char);

/// One `@Name` found in a text: `[start, end)` names [userId].
class MentionMatch {
  const MentionMatch(this.start, this.end, this.userId);

  final int start;
  final int end;
  final String userId;
}

/// Finds `@Name` mentions of [users] in [text], in text order. Names match
/// exactly and must stand alone ("mail@Anna" and "@Annabel" do not mention
/// Anna). Longer names win, so "@Anna Lee" is not also "@Anna".
List<MentionMatch> findMentions(String text, Iterable<MemberUser> users) {
  final byLength = users.where((u) => u.name.trim().isNotEmpty).toList()
    ..sort((a, b) => b.name.length.compareTo(a.name.length));
  final matches = <MentionMatch>[];
  for (final user in byLength) {
    final needle = '@${user.name}';
    for (var start = text.indexOf(needle); start >= 0;) {
      final end = start + needle.length;
      final standsAlone =
          (start == 0 || !_isWordChar(text[start - 1])) &&
          (end == text.length || !_isWordChar(text[end]));
      final taken = matches.any((m) => start < m.end && m.start < end);
      if (standsAlone && !taken) matches.add(MentionMatch(start, end, user.id));
      start = text.indexOf(needle, start + 1);
    }
  }
  return matches..sort((a, b) => a.start.compareTo(b.start));
}

/// Ids of the members [text] mentions, in order of first mention.
List<String> mentionedIds(String text, Iterable<MemberUser> users) => {
  for (final match in findMentions(text, users)) match.userId,
}.toList();

/// The `@query` being typed right before the cursor.
class MentionQuery {
  const MentionQuery(this.start, this.query);

  /// Index of the `@`.
  final int start;

  /// Text between the `@` and the cursor.
  final String query;
}

/// The mention being typed at [cursor], or `null`.
MentionQuery? mentionQueryAt(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final before = text.substring(0, cursor);
  final at = before.lastIndexOf('@');
  if (at < 0 || (at > 0 && _isWordChar(before[at - 1]))) return null;
  final query = before.substring(at + 1);
  if (query.length > 40 || query.contains('\n')) return null;
  return MentionQuery(at, query);
}

/// Members whose name (any word of it) or e-mail starts with [query].
List<MemberUser> mentionSuggestions(
  String query,
  Iterable<MemberUser> users, {
  int limit = 5,
}) {
  final q = query.toLowerCase();
  bool matches(MemberUser u) {
    final name = u.name.toLowerCase();
    return name.startsWith(q) ||
        name.split(' ').any((word) => word.startsWith(q)) ||
        u.email.toLowerCase().startsWith(q);
  }

  return users.where(matches).take(limit).toList();
}

/// Replaces the typed `@query` with `@Name ` and returns the new text and
/// cursor position.
({String text, int cursor}) insertMention(
  String text,
  MentionQuery query,
  int cursor,
  String name,
) {
  final mention = '@$name ';
  return (
    text: text.replaceRange(query.start, cursor, mention),
    cursor: query.start + mention.length,
  );
}
